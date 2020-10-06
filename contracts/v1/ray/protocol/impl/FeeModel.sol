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


// external dependencies
import "./openzeppelin/math/SafeMath.sol";

// internal dependencies
import "../interfaces/INAVCalculator.sol";
import "../interfaces/Upgradeable.sol";

import "./Storage.sol";
import "./wrappers/StorageWrapper.sol";
import "./wrappers/StorageWrapperTwo.sol";


/// @notice  Models the fee logic, currently takes a percentage of the yield
///          earnt over a benchmark rate
///
/// Author:  Devan Purhar
/// Version: 1.0.0

contract FeeModel is Upgradeable {
  using SafeMath
  for uint256;


  /*************** STORAGE VARIABLE DECLARATIONS **************/


  // contracts used
  bytes32 internal constant STORAGE_WRAPPER_CONTRACT = keccak256("StorageWrapperContract");
  bytes32 internal constant STORAGE_WRAPPER_TWO_CONTRACT = keccak256("StorageWrapperTwoContract");
  bytes32 internal constant NAV_CALCULATOR_CONTRACT = keccak256("NAVCalculatorContract");
  bytes32 internal constant ADMIN_CONTRACT = keccak256("AdminContract");

  uint internal constant ON_CHAIN_PRECISION = 1e18;
  uint internal constant SECONDS_PER_YEAR = 84600 * 365;

  uint public rayFee = 5; // 20%

  Storage public _storage;
  bool public deprecated;


  /*************** MODIFIER DECLARATIONS **************/


  /// @notice  Requires the sender be one of our Portfolio Manager's
  modifier onlyPortfolioManager(bytes32 contractId)
  {
      require(
          msg.sender == _storage.getVerifier(contractId),
          "#FeeModel onlyPortfolioManager Modifier: This is not a valid contract calling"
      );

      _;
  }


  /// @notice  Checks the caller is our Admin contract
  modifier onlyAdmin()
  {

    require(
      msg.sender == _storage.getContractAddress(ADMIN_CONTRACT),
      "#FeeModel onlyAdmin Modifier: Only the Admin contract can call this"
    );

    _;

  }


  /// @notice  Checks if the contract has been set to deprecated
  modifier notDeprecated()
  {
      require(
           deprecated == false,
          "#FeeModel notDeprecated Modifier: In deprecated mode - this contract has been deprecated"
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


  /** --------------- PortfolioManager ENTRYPOINTS ----------------- **/


  /// @notice  Updates the token allowance of a token
  ///
  /// @param   portfolioId - The portfolio id
  /// @param   tokenId - The unique id of the token
  function updateAllowance(
    bytes32 portfolioId,
    bytes32 tokenId
  )
    external
    notDeprecated
    onlyPortfolioManager(portfolioId)
    returns(uint)
  {

    uint tokenCapital = _storage.getTokenCapital(portfolioId, tokenId);
    uint tokenAllowance = calculateAllowance(portfolioId, tokenId, tokenCapital);

    // this call does not decrement the allowance, only keeps same or increments
    StorageWrapperTwo(_storage.getContractAddress(STORAGE_WRAPPER_TWO_CONTRACT)).setTokenAllowance(portfolioId, tokenId, tokenAllowance);

    return tokenAllowance;

  }


  /// @notice  Part 1 of 2 that takes our fee on yield we've generated if eligible
  ///
  /// @param   portfolioId - The portfolio id
  /// @param   tokenId - The unique id of the token that is withdrawing
  /// @param   valueToWithdraw - The value the token is withdrawing
  function takeFee(
    bytes32 portfolioId,
    bytes32 tokenId,
    uint valueToWithdraw,
    uint tokenValue
  )
    external
    notDeprecated
    onlyPortfolioManager(portfolioId)
    returns(uint)
  {

      // first step: calculate new total allowance
      uint tokenCapital = _storage.getTokenCapital(portfolioId, tokenId);
      uint tokenAllowance = calculateAllowance(portfolioId, tokenId, tokenCapital);

      // second step: find how much proportionate yield we're withdrawing
      uint yield = calculateYield(portfolioId, tokenId, tokenCapital, tokenValue);

      uint percentageOfValue = valueToWithdraw * ON_CHAIN_PRECISION / tokenValue; // what % of the token value we're withdrawing
      uint percentageOfYield = yield * percentageOfValue / ON_CHAIN_PRECISION; // amount we're going to withdraw from our yield
      uint percentageOfAllowance = tokenAllowance * percentageOfValue / ON_CHAIN_PRECISION; // amount of allowance we apply for this withdrawal

      // remove token capital being withdrawn
      updateTokenCapital(portfolioId, tokenId, tokenCapital, percentageOfValue);

       return takeFee2(
         portfolioId,
         tokenId,
         percentageOfYield,
         percentageOfAllowance,
         tokenAllowance,
         valueToWithdraw
       );

  }


  /** ----------------- ONLY ADMIN MUTATORS ----------------- **/


  /// @notice   Set the fee we take on yield earnt
  ///
  /// @dev      No verification of what's input takes place currently
  ///           Ex. input. For 20%, newFee = 5
  ///
  /// @param    newFee - The new fee to use
  function setRAYFee(uint newFee) external onlyAdmin notDeprecated {

    rayFee = newFee;

  }


  /// @notice  Sets the deprecated flag of the contract
  ///
  /// @dev     Used when upgrading a contract
  ///
  /// @param   value - true to deprecate, false to un-deprecate
  function setDeprecated(bool value) external onlyAdmin {

      deprecated = value;


  }


  /** ----------------- ANYONE CAN MUTATE ----------------- **/


  /// @notice  Updates the cumulative rate based on the benchmark rate
  ///
  /// @param   principalAddress - The coin address
  ///
  /// NOTE: Turned visibilty from internal to public because we call it from
  ///       'Admin' when updating the rate. This can be public with **no** modifier
  ///        because people can't abuse calling it. They can enter an invalid address
  ///        and it won't affect any real portfolios or the rest of the contract.
  ///        They can enter a real address and simply update the cumulative rate with
  ///        their own gas. Don't need to check if it's a valid portfolio b/c
  ///        if it isn't the rate will be 0 so the result will always be 0 anyway
  ///
  /// NOTE: The miner can push block.timestamp to be up to 15 minutes in the future
  ///       This isn't ideal but it won't cause too big of a negative impact. The
  ///       cumulative rate will be a tiny bit bigger then it should be meaning we
  ///       will receive slightly less fees. This could add up if it were to happen
  ///       over and over but if every miner did that the chain would be corrupted.
  function updateCumulativeRate(address principalAddress) public notDeprecated returns(uint) {

      // this can never underflow, a miner can't change the timestamp so that
      // it is less than it's previous block. If multiple tx's come in on the same
      // block, timeSinceLastUpdate will be 0 as it should be.
      uint timeSinceLastUpdate = now - _storage.getLastUpdatedRate(principalAddress);

      // TODO: should add if (timeSinceLastUpdate > 0) to save on unneccessary gas from manip. storage
      // 0 is possible since multiple transactions could come in the same block for the same portfolio

      uint rateToAdd = ((timeSinceLastUpdate * (_storage.getBenchmarkRate(principalAddress) * ON_CHAIN_PRECISION / SECONDS_PER_YEAR)) / ON_CHAIN_PRECISION); // leave it scaled up 1e18

      uint cumulativeRate = _storage.getCumulativeRate(principalAddress) + rateToAdd;
      StorageWrapperTwo(_storage.getContractAddress(STORAGE_WRAPPER_TWO_CONTRACT)).setCumulativeRate(principalAddress, cumulativeRate);
      StorageWrapperTwo(_storage.getContractAddress(STORAGE_WRAPPER_TWO_CONTRACT)).setLastUpdatedRate(principalAddress, now);

      return cumulativeRate;

  }



  /********************* INTERNAL FUNCTIONS **********************/


  /// @notice  Reduce the tokens capital after a withdraw
  ///
  /// @param   portfolioId - The portfolio id
  /// @param   tokenId - The unique token id of which we're updating
  /// @param   tokenCapital - The current token capital
  /// @param   percentageOfValue - The percentage of value being withdrawn
  ///
  /// TODO: Refactor name to "reduceCapital()"
  function updateTokenCapital(
    bytes32 portfolioId,
    bytes32 tokenId,
    uint tokenCapital,
    uint percentageOfValue
  )
    internal
  {

    // amount we're going to withdraw from their capital
    uint percentageOfCapital = tokenCapital * percentageOfValue / ON_CHAIN_PRECISION;

    // this can only underflow if percentageOfValue somehow exceeds 100% so shouldn't check for it
    // but do anyway for now (audit suggestion)
    uint newTokenCapital = SafeMath.sub(tokenCapital, percentageOfCapital); // === tokenCapital - percentageOfCapital === capital - capitalBeingWithdrawn
    StorageWrapper(_storage.getContractAddress(STORAGE_WRAPPER_CONTRACT)).setTokenCapital(portfolioId, tokenId, newTokenCapital);

  }


  /// @notice  Part 2 of 2 of taking fees upon a withdrawal
  ///
  /// @dev     Split up to avoid stack to deep error
  ///
  /// @param    portfolioId - The portfolio id
  /// @param    tokenId - The unique token id withdrawing
  /// @param    percentageOfYield - The proportionate yield being withdrawn
  /// @param    percentageOfAllowance - The proportionate allowance being applied
  /// @param    tokenAllowance - The total token allowance
  /// @param    valueToWithdraw - The value being withdrawn
  function takeFee2(
    bytes32 portfolioId,
    bytes32 tokenId,
    uint percentageOfYield,
    uint percentageOfAllowance,
    uint tokenAllowance,
    uint valueToWithdraw
  )
    internal
    returns (uint)
  {

    // if they are claiming more than the amount we take no fee on as it we take
    // it at this time and add it to acp contribution
   if (percentageOfYield > percentageOfAllowance) {

       address principalAddress = _storage.getPrincipalAddress(portfolioId);

       // could put a check to make sure yield chargin on > fee (5 wei) but will be somewhat useless -> waste of gas
       // line below can't underflow due to if() ^
       uint acpContribution = (percentageOfYield - percentageOfAllowance) / rayFee;

       // shouldn't ever overflow though we can dream it's a danger too :)
       StorageWrapperTwo(_storage.getContractAddress(STORAGE_WRAPPER_TWO_CONTRACT)).setACPContribution(portfolioId, _storage.getACPContribution(principalAddress) + acpContribution);

       // shouldn't ever underflow since it's a percentage base of the total, so it underflows if the percentage exceeds 100%
       // but we add a check anyway for now (audit suggestion), it was tokenAllowance - percentageOfAllowance
       StorageWrapperTwo(_storage.getContractAddress(STORAGE_WRAPPER_TWO_CONTRACT)).setTokenAllowance(portfolioId, tokenId, SafeMath.sub(tokenAllowance, percentageOfAllowance));

       // valueToWithdraw can never be < than the acpContribution since the
       // acpContribution is 20% of the valueToWithdraw
       return valueToWithdraw - acpContribution;

     } else {

       // shouldn't ever underflow since it's a percentage base of the total, so it underflows if the percentage exceeds 100%
       // but we add a check anyway for now (audit suggestion), it was tokenAllowance - percentageOfYield
       StorageWrapperTwo(_storage.getContractAddress(STORAGE_WRAPPER_TWO_CONTRACT)).setTokenAllowance(portfolioId, tokenId, SafeMath.sub(tokenAllowance, percentageOfYield));
       return valueToWithdraw;

     }

  }


  /// @notice  Calculate the allowance deserved for the token withdrawing
  ///
  /// @param   portfolioId - The portfolio id
  /// @param   tokenId - The token id of the token withdrawing
  /// @param   capital - The tokens current capital
  ///
  /// @return  The total token allowance (old + new)
  function calculateAllowance(
    bytes32 portfolioId,
    bytes32 tokenId,
    uint capital
  )
    internal
    returns(uint)
  {

    address principalAddress = _storage.getPrincipalAddress(portfolioId);
    uint cumulativeRate = updateCumulativeRate(principalAddress);

    // below line can't underflow, the cumulativeRate can't decrease in value, the benchmark rate is an unsigned integer
    uint applicableRate = (cumulativeRate - _storage.getEntryRate(portfolioId, tokenId)); // this is scaled up by ON_CHAIN_PRECISION
    uint tokenAllowance = _storage.getTokenAllowance(portfolioId, tokenId) + (capital * applicableRate / ON_CHAIN_PRECISION); // capital may be zero but not a worry if it is
    StorageWrapperTwo(_storage.getContractAddress(STORAGE_WRAPPER_TWO_CONTRACT)).setEntryRate(portfolioId, tokenId, cumulativeRate); // update entry rate to current time, effectively resetting to zero

    return tokenAllowance;

  }


  /// @notice  Calculate the proportionate yield to withdraw
  ///
  /// @param   portfolioId - The portfolio id
  /// @param   tokenId - The token id withdrawing
  /// @param   tokenCapital - The current capital of this token
  function calculateYield(
    bytes32 portfolioId,
    bytes32 tokenId,
    uint tokenCapital,
    uint tokenValue
  )
    internal
    view
    returns (uint)
  {

    uint yield;

    // check for < since potential to underflow since we round up when taking value from tokenValue
    if (tokenValue <= tokenCapital) {

      yield = 0;

    } else {

      // can't underflow due to if() ^
      yield = tokenValue - tokenCapital;

    }

    return yield;

  }


}
