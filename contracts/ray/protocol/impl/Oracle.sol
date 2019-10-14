/**

    The software and documentation available in this repository (the "Software") is
    protected by copyright law and accessible pursuant to the license set forth below.

    Copyright © 2019 Staked Securely, Inc. All rights reserved.

    Permission is hereby granted, free of charge, to any person or organization
    obtaining the Software (the “Licensee”) to privately study, review, and analyze
    the Software. Licensee shall not use the Software for any other purpose. Licensee
    shall not modify, transfer, assign, share, or sub-license the Software or any
    derivative works of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
    INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
    PARTICULAR PURPOSE, TITLE, AND NON-INFRINGEMENT. IN NO EVENT SHALL THE COPYRIGHT
    HOLDERS BE LIABLE FOR ANY DAMAGES OR OTHER LIABILITY, WHETHER IN CONTRACT, TORT,
    OR OTHERWISE, ARISING FROM, OUT OF, OR IN CONNECTION WITH THE SOFTWARE.

*/

pragma solidity 0.4.25;


// external dependency
import "./openzeppelin/math/SafeMath.sol";

// internal dependencies
import "../interfaces/IPortfolioManager.sol";
import "../interfaces/INAVCalculator.sol";
import "../interfaces/Opportunity.sol";
import "../interfaces/Upgradeable.sol";

import "./Storage.sol";
import "./wrappers/StorageWrapperTwo.sol";


/// @notice  Oracle is the contract that receives instructions from our off-chain
///          'oracle' which tells it where and what the optimal allocations of capital are.
///
///          Eventually we'll upgrade this contract to sample from different
///          oracles and take the median, or some sort of consensus logic,
///          possibly like MakerDAO's Medianizer for prices. The goal is to
///          decentralize the oracle.
///
///          We currently run the oracle as an off-chain microservice because
///          the calculations we wish to do will be too complex to carry out
///          on-chain, as we scale to many more opportunities.
///
///          !! Due to the design of the smart contracts, the runner of the
///          oracle(s) CAN'T steal any funds. The worst they could do is direct
///          funds into the lowest yielding opportunity. Due to this, Staked
///          only has strong economic incentives to run the single oracle properly.
///
///          We only create revenue IF the oracle is functioning optimally and we
///          can't steal the funds through the oracle.
///
/// Author:   Devan Purhar
/// Version:  1.0.0

contract Oracle is Upgradeable {


  /*************** STORAGE VARIABLE DECLARATIONS **************/


  // contracts used
  bytes32 internal constant NAV_CALCULATOR_CONTRACT = keccak256("NAVCalculatorContract");
  bytes32 internal constant ADMIN_CONTRACT = keccak256("AdminContract");
  bytes32 internal constant STORAGE_WRAPPER_TWO_CONTRACT = keccak256("StorageWrapperTwoContract");

  uint internal constant ON_CHAIN_PRECISION = 1e18;

  Storage public _storage;
  bool public deprecated;


  /*************** EVENT DECLARATIONS **************/


  /// @notice  Logs when withdrawing from an Opportunity
  ///
  /// TODO: Check if this logs the same data as an event in OpportunityManager
  event LogWithdrawFromPortfolio(
    bytes32 portfolioKey,
    bytes32 opportunityKey,
    uint value
  );

  /// @notice  Logs the extra value we withdrew from the Opportunities that the
  ///          RAY Token didn't have credit for.
  event LogOpportunityDust(
    bytes32 key,
    uint dust
  );

  /*************** MODIFIER DECLARATIONS **************/


  /// @notice  Checks the caller is an approved [off-chain] Oracle
  modifier onlyOracles()
  {

    require(
      _storage.getIsOracle(msg.sender) == true,
      "#Oracle onlyOracles Modifier: Only Oracles can call this"
    );

    _;

  }


  /// @notice  Checks the caller is our Admin contract
  modifier onlyAdmin()
  {

    require(
      _storage.getContractAddress(ADMIN_CONTRACT) == msg.sender,
      "#Oracle onlyAdmin Modifier: Only Admin can call this"
    );

    _;

  }


  /// @notice  Checks the caller is one of our PortfolioManager contracts
  modifier onlyPortfolioManager(bytes32 contractId)
  {
      require(
           _storage.getVerifier(contractId) == msg.sender,
          "#Oracle onlyPortfolioManager Modifier: Only valid RAY contracts can call this"
      );

      _;
  }


  /// @notice  Checks if the contract has been set to deprecated
  modifier notDeprecated()
  {
      require(
           deprecated == false,
          "#Oracle notDeprecated Modifier: In deprecated mode - this contract has been deprecated"
      );

      _;
  }


  /////////////////////// FUNCTION DECLARATIONS BEGIN ///////////////////////

  /******************* PUBLIC FUNCTIONS *******************/


  /// @notice  Sets the Storage contract instance
  ///
  /// @param   __storage - The Storage contracts address
  constructor(address __storage) public {

    _storage = Storage(__storage);

  }


  /** --------------- OFF-CHAIN ORACLE ENTRYPOINTS (ONLY ORACLE) ----------------- **/


  /// @notice  Entrypoint for the off-chain oracle to instruct initial lending
  ///
  /// @param   key - The portfolio key to lend too
  /// @param   opportunityKey - The opportunity key of the opportunity we want to lend too
  /// @param   opportunity - The opportunity's contract address we're lending too (ours not the third-party one)
  /// @param   value - The value we're lending in-kind smallest units
  function lend(
    bytes32 key,
    bytes32 opportunityKey,
    address opportunity,
    uint value
  )
    external
    onlyOracles
    notDeprecated
  {

    // require(value > 0, "#Oracle lend(): Need to lend greater than 0  in value"); // covered by PositionManager verifyAmount()
    require(value <= _storage.getAvailableCapital(key), "#Oracle lend(): Not enough available capital in this portfolio to lend this value");

    IPortfolioManager(_storage.getVerifier(key)).lend(key, opportunityKey, opportunity, value, true);

  }


  /// @notice  Entrypoint for the off-chain oracle to carry out rebalances. We
  ///          have this function to make it faster/more efficient to rebalance.
  ///
  /// @dev     All indexes must be correlated across the same type (w or l)
  ///
  /// @param   wOpportunityKeys - The opportunity keys of platforms we're withdrawing from
  /// @param   wOpps - The opportunity contract addresses of the platforms we're withdrawing from
  /// @param   wValues - The amount we're withdrawing
  /// @param   lOpportunityKeys - The opportunity keys of platforms we're lending to
  /// @param   lOpps - The opportunity contract addresses of the platforms we're lending to
  /// @param   lValues - The amount we're lending to
  function rebalance(
    bytes32 key,
    bytes32[] memory wOpportunityKeys,
    address[] memory wOpps,
    uint[] memory wValues,
    bytes32[] memory lOpportunityKeys,
    address[] memory lOpps,
    uint[] memory lValues
  )
    public // not external b/c we use memory to pass in the arrays
    onlyOracles
    notDeprecated
  {

    // notPaused(key); // checked in PortfolioManager

    // entering invalid portfolios will throw not at our check in PortfolioManager,
    // but when it tries to call the address in verifier (which would be NULL/false)

    uint totalWithdrawn;
    uint totalLent;

    // Watch for breaching the block gas limit on for loops like this - it's fine
    // for now but need to check how scalable in the future.
    for (uint i = 0; i < wOpps.length; i++) {

      IPortfolioManager(_storage.getVerifier(key)).withdraw(key, wOpportunityKeys[i], wOpps[i], wValues[i], false);

      totalWithdrawn += wValues[i];

    }

    // Watch for breaching the block gas limit on for loops like this - it's fine
    // for now but need to check how scalable in the future
    for (i = 0; i < lOpps.length; i++) {

      IPortfolioManager(_storage.getVerifier(key)).lend(key, lOpportunityKeys[i], lOpps[i], lValues[i], false);

      totalLent += lValues[i];

    }

    uint currAvailableCapital =  _storage.getAvailableCapital(key);

    require(totalLent <= (totalWithdrawn + currAvailableCapital), "#Oracle rebalance(): The amount lent out must be less than or equal to the amount withdrawn + the available capital");

    if (totalLent > totalWithdrawn) {

      uint amountFromAvailableCapital = totalLent - totalWithdrawn;

      uint newAvailableCapital = SafeMath.sub(currAvailableCapital, amountFromAvailableCapital); // will revert if underflows
      StorageWrapperTwo(_storage.getContractAddress(STORAGE_WRAPPER_TWO_CONTRACT)).setAvailableCapital(key, newAvailableCapital);

    }

  }


  /** ----------------- ONLY ADMIN MUTATORS ----------------- **/


  /// @notice  Only called when we're withdrawing from PortfolioManager on an upgrade
  ///
  /// @param   key - The portfolio key we're withdrawing from
  /// @param   opportunityKey - The opportunity key we're withdrawing from
  /// @param   opportunity - The contract address of the opportunity
  /// @param   value - The value in-kind in the smallest units we're withdrawing
  function withdraw(
    bytes32 key,
    bytes32 opportunityKey,
    address opportunity,
    uint value
  )
    external
    onlyAdmin
    notDeprecated
  {

    IPortfolioManager(_storage.getVerifier(key)).withdraw(key, opportunityKey, opportunity, value, true);

  }


  /// @notice  Sets the deprecated flag of the contract
  ///
  /// @dev     Used when upgrading a contract
  ///
  /// @param   value - true to deprecate, false to un-deprecate
  function setDeprecated(bool value) external onlyAdmin {

      deprecated = value;

  }


  /** ----------------- ONLY RAY(S) MUTATORS ----------------- **/


  /// @notice  Tells the PortfolioManager which protocols to withdraw from upon a
  ///          withdrawal request from a user.
  ///
  /// @dev     This is hard-coded currently in order of withdrawal from Opportunities
  ///
  /// @param   key - The portfolio key to use to find the Opportunities of this portfolio
  /// @param   valueToWithdraw - The amount to withdraw in total.
  /// @param   totalValue - The tokens total value, used to not withdraw more value then allowed
  ///
  /// @return  The amount of value to add to the top-level tokens withdrawal
  ///
  /// TODO:    Don't hard-code, maybe keep a map of spots each Opp. is ranked in and
  ///          update off some threshold. Currently this will just withdraw from the first
  ///          protocols that have enough value, it loops through based on what order
  ///          they were added in. A rebalance will re-optimize the amounts
  function withdrawFromProtocols(
    bytes32 key,
    uint valueToWithdraw,
    uint totalValue
  )
    public
    notDeprecated
    onlyPortfolioManager(key)
    returns (uint)
  {

    uint totalDust;
    uint leftToWithdraw = valueToWithdraw;

    leftToWithdraw = considerAvailableCapital(key, leftToWithdraw);

    if (leftToWithdraw == 0) {
      return 0;
    }

    // I think it's better UX to let revert then return less then requested funds.
    // We check the market is liquid enough off-chain now BEFORE the request to
    // withdraw is ever made to avoid that scenario anyway

    bytes32[] memory opportunities;
    opportunities = _storage.getOpportunities(key);

    // Watch for breaching the block gas limit on for loops like this, it's fine
    // now but need to check how scalable in the future
   for (uint i = 0; i < opportunities.length; i++) {

       bytes32 opportunityKey = opportunities[i];
       address opportunity = _storage.getVerifier(opportunityKey);
       uint opportunityBalance = INAVCalculator(_storage.getContractAddress(NAV_CALCULATOR_CONTRACT)).getOpportunityBalance(key, opportunityKey);

       if (opportunityBalance <= 0) {

         continue;

       }

       (totalDust, leftToWithdraw) = executeWithdraw(
         key,
         opportunityKey,
         opportunity,
         leftToWithdraw,
         opportunityBalance,
         totalDust
       );

       if (leftToWithdraw == 0) {

         break;

       }

   }

   if ((valueToWithdraw + totalDust) > totalValue) {

     uint overflow = (valueToWithdraw + totalDust) - totalValue;
     totalDust -= overflow;

     emit LogOpportunityDust(key, overflow);

   }

   return totalDust;

}


  /// @notice  Consider withdrawing from the available capital of the portfolio
  ///          on withdrawals.
  ///
  /// @return  The value left to withdraw
  function considerAvailableCapital(
    bytes32 key,
    uint valueToWithdraw
  )
    internal
    returns(uint)
  {

    uint availableCapital = _storage.getAvailableCapital(key);

    if (valueToWithdraw <= availableCapital) {

      StorageWrapperTwo(_storage.getContractAddress(STORAGE_WRAPPER_TWO_CONTRACT)).setAvailableCapital(key, availableCapital - valueToWithdraw);
      return 0;

    } else if (availableCapital > 0) {

      StorageWrapperTwo(_storage.getContractAddress(STORAGE_WRAPPER_TWO_CONTRACT)).setAvailableCapital(key, 0);
      valueToWithdraw -= availableCapital;

    }

    return valueToWithdraw;

  }


  /// @notice  Execute the withdrawal
  ///
  /// @return  The total dust we'll be withdrawing and the updated value left to withdraw
  function executeWithdraw(
    bytes32 key,
    bytes32 opportunityKey,
    address opportunity,
    uint valueToWithdraw,
    uint opportunityBalance,
    uint totalDust
  )
    internal
    returns(uint, uint)
  {

    // TODO: maybe don't check for equality so we don't unneccessarily call flatten
    if (valueToWithdraw <= opportunityBalance) {

      uint dust = flattenNumber(key, opportunityKey, opportunity, valueToWithdraw);
      valueToWithdraw += dust;
      totalDust += dust;
      IPortfolioManager(_storage.getVerifier(key)).withdraw(key, opportunityKey, opportunity, valueToWithdraw, false);

      return (totalDust, 0);

    } else {

      valueToWithdraw -= opportunityBalance;
      IPortfolioManager(_storage.getVerifier(key)).withdraw(key, opportunityKey, opportunity, opportunityBalance, false);

      return (totalDust, valueToWithdraw);

    }

  }


  /// @notice  Flattens the number of shares we'll be withdrawing from an Opportunity
  ///          token.
  ///
  /// @return  The extra value to withdraw
  function flattenNumber(
    bytes32 key,
    bytes32 opportunityKey,
    address opportunity,
    uint valueToWithdraw
  )
    internal
    view
    returns (uint)
  {

    uint shares = _storage.getTokenShares(opportunityKey, _storage.getOpportunityToken(key, opportunityKey));
    uint pricePerShare = INAVCalculator(_storage.getContractAddress(NAV_CALCULATOR_CONTRACT)).getOpportunityPricePerShare(opportunityKey);
    uint raised = _storage.getRaised(_storage.getPrincipalAddress(key));

    uint beforeCeilingShares = calculateShares(valueToWithdraw, shares, pricePerShare, raised);
    uint afterCeilingShares = calculateCeiling(beforeCeilingShares, 10);

    if (afterCeilingShares > shares) {

      afterCeilingShares = shares;

    }

    uint extraShares = afterCeilingShares - beforeCeilingShares;

    return (pricePerShare * extraShares / ON_CHAIN_PRECISION);

  }


  /// @notice  Calculate the shares we need to redeem for a certain value to be withdrawn
  ///          from the system.
  ///
  /// @return  the number of shares
  function calculateShares(
    uint valueToWithdraw,
    uint shares,
    uint pricePerShare,
    uint raised
  )
    internal
    view
    returns(uint)
  {

    uint beforeCeilingPercentage = (valueToWithdraw * raised / ((shares * pricePerShare) / raised));
    uint beforeCeilingShares = (shares * beforeCeilingPercentage / raised);

    return beforeCeilingShares;

  }


  /// @notice  Find the ceiling of a divisions result
  ///
  /// @return  The ceiling of the result
  function calculateCeiling(uint a, uint m) internal pure returns (uint) {
     return ((a + m - 1) / m) * m;
 }


}
