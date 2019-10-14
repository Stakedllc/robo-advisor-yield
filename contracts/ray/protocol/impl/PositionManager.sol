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

// internal dependency
import "../interfaces/IRAYToken.sol";
import "../interfaces/Upgradeable.sol";

import "./Storage.sol";
import "./wrappers/TokenWrapper.sol";
import "./wrappers/StorageWrapper.sol";


/// @notice  PositionManager handles all the 'token' mutations of storage. It
///          manipulates both RAY and Opportunity tokens. A token represents a
///          posiiton, hence 'Position'Manager. RAY tokenizes positions, therefore
///          the terminology token and position are equivalent.
///
/// Author:  Devan Purhar
/// Version: 1.0.0

contract PositionManager is Upgradeable {
  using SafeMath
  for uint256;


  /*************** STORAGE VARIABLE DECLARATIONS **************/


  // contracts used
  bytes32 internal constant ADMIN_CONTRACT = keccak256("AdminContract");
  bytes32 internal constant OPPORTUNITY_MANAGER_CONTRACT = keccak256("OpportunityManagerContract");
  bytes32 internal constant TOKEN_WRAPPER_CONTRACT = keccak256("TokenWrapperContract");
  bytes32 internal constant STORAGE_WRAPPER_CONTRACT = keccak256("StorageWrapperContract");

  uint internal constant ON_CHAIN_PRECISION = 1e18;
  uint internal constant BASE_PRICE_IN_WEI = 1 wei;

  Storage public _storage;
  bool public deprecated;


  /*************** MODIFIER DECLARATIONS **************/


  /// @notice  Requires the caller is either a valid version of PortfolioManager
  ///          or our OpportunityManager contract
  ///
  /// @param   typeId - The portfolio / opportunity id we're operating for
  modifier onlyPortfolioOrOpportunityManager(bytes32 typeId)
  {
      require(
          _storage.getVerifier(typeId) == msg.sender ||
          _storage.getContractAddress(OPPORTUNITY_MANAGER_CONTRACT) == msg.sender,
          "#PositionManager onlyPortfolioOrOpportunityManager Modifier: This is not a valid contract calling"
      );

      _;
  }


  /// @notice  Verifies the amount being add or withdrawn is above the min. amount
  ///
  /// @dev     We currently have a min. amount we set per coin.
  ///
  ///          We used to enforce the technical minimum, which is the user must
  ///          be adding or withdrawing at least the price of 1 share. That'll
  ///          start at 1 wei and go up as we make returns. If they don't do at
  ///          at least one share worth the division we do with price per share
  ///          will result in 0 since the denominator will be > then numerator.
  ///
  /// TODO:    Remove the min. amount, re-use the enforcement of buying/withdrawing
  ///          at least 1 share
  modifier verifyAmount(bytes32 typeId, uint value)
  {

    address principalAddress = _storage.getPrincipalAddress(typeId);

    require(
        value > _storage.getMinAmount(principalAddress),
        "#PositionManager verifyAmount Modifier: Cannot add or withdraw less than the minimum amount"
    );

    _;

  }


  /// @notice  Requires the caller is our Admin contract
  modifier onlyAdmin()
  {

    require(
      msg.sender == _storage.getContractAddress(ADMIN_CONTRACT),
      "#PositionManager onlyAdmin Modifier: Only Admin can call this"
    );

    _;

  }


  modifier notDeprecated()
  {
      require(
           deprecated == false,
          "#PositionManager notDeprecated Modifier: In deprecated mode - this contract has been deprecated"
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


  /** --------------- Portfolio/OpportunityManager ENTRYPOINTS ----------------- **/


  /// @notice  Creates either a RAY [RAYT] or Opportunity Token [OT]
  ///
  /// @dev     If PortfolioManager is calling it'll be creating a RAYT, if OpportunityManager
  ///          is calling it'll be creating an OT.
  ///
  ///          We currently only allow RAYT's or OT's to be created through
  ///          our contracts so we enforce one of those two contracts are the caller.
  ///
  /// @param   typeId - The id of the portfolio/opportunity the token
  ///                           will be representing a stake in the pool of value in.
  /// @param   token - The token contract address, either RAYT or OT
  /// @param   beneficiary - The owner of the token, either the user (RAYT) or
  ///                        PortfolioManager (OT)
  /// @param   value - The capital value credited to the token
  /// @param   pricePerShare - The PPS the token is buying in at
  ///
  /// @return  The unique token id
  function createToken(
    bytes32 typeId,
    address token,
    address beneficiary,
    uint value,
    uint pricePerShare
  )
    external
    notDeprecated
    onlyPortfolioOrOpportunityManager(typeId)
    verifyAmount(typeId, value)
    returns (bytes32)
  {

    bytes32 tokenId = TokenWrapper(_storage.getContractAddress(TOKEN_WRAPPER_CONTRACT)).mintRAYToken(typeId, beneficiary, token);

    uint numOfShares = calculatePremiumValue(typeId, value, pricePerShare);

    createToken2(
        typeId,
        tokenId,
        value,
        numOfShares
    );

    return tokenId;

  }


  /// @notice  Increase the value associated with a given RAYT or OT
  ///
  /// @dev     We don't allow anyone to add value to a OT at this time,
  ///          but we could.
  ///
  /// @param   typeId - The portfolio (RAYT) / opportunity (OT) id
  ///                           the token represents a stake of value in
  /// @param   tokenId - The unique id of the token
  /// @param   pricePerShare - The PPS the token is adding value in at
  /// @param   value - The amount of value being added to the token
  function increaseTokenCapital(
      bytes32 typeId,
      bytes32 tokenId,
      uint pricePerShare,
      uint value
  )
      external
      notDeprecated
      onlyPortfolioOrOpportunityManager(typeId)
      verifyAmount(typeId, value)
  {

      uint numOfShares = calculatePremiumValue(typeId, value, pricePerShare);

      uint tokenCapital = _storage.getTokenCapital(typeId, tokenId);
      uint newTokenCapital = tokenCapital + value;
      StorageWrapper(_storage.getContractAddress(STORAGE_WRAPPER_CONTRACT)).setTokenCapital(typeId, tokenId, newTokenCapital);

      increaseTokenCapital3(typeId, tokenId, numOfShares);

    }


    /// @notice  Verifies the address attempting a withdrawal is the owner of
    ///          of the token, and the amount they're trying to withdraw is possible
    ///
    /// @param   typeId - The portfolio (RAYT) / opportunity (OT) id
    ///                           the token represents a stake of value in
    /// @param   tokenId - The unique id of the token
    /// @param   token - The token contract address, either RAYT or OT
    /// @param   sender - The address who sent the withdrawal request, we trust
    ///                   this is the true sender since our own contracts pass this
    /// @param   valueToWithdraw - The amount being withdrawn
    /// @param   totalValue - The total value using the current PPS the token has (including yield made)
    function verifyWithdrawer(
      bytes32 typeId,
      bytes32 tokenId,
      address token,
      address sender,
      uint /*pricePerShare*/, // used to use in verifyAmount, re-implementing some logic that'll use it again in the future
      uint valueToWithdraw,
      uint totalValue
    )
      external
      view
      notDeprecated
      onlyPortfolioOrOpportunityManager(typeId)
      verifyAmount(typeId, valueToWithdraw)
      returns (address)
    {

        address beneficiary = IRAYToken(token).ownerOf(uint(tokenId));

        require(sender == beneficiary, "#PositionManager verifyWithdrawer(): Only the owner can withdraw funds from a RAYT or Opportunity Token");
        require(totalValue >= valueToWithdraw, "#PositionManager verifyWithdrawer(): Not enough value in RAYT or Opportunity Token to withdraw");

        return beneficiary;

    }


    /// @notice  Reduces different properties of a token when they withdraw, as
    ///          well as global variables in the token's portfolio state
    ///
    /// @param   typeId - The portfolio (RAYT) / opportunity (OT) id
    ///                   the token represents a stake of value in
    /// @param   tokenId - The unique id of the token
    /// @param   valueToWithdraw - The amount being withdrawn
    /// @param   pricePerShare - The PPS the token is withdrawing value out at (current value)
    /// @param   shares - The shares this token is credited with
    /// @param   unrealizedYield - The amount of yield sitting in platforms this
    ///                            portfolio has credit too
    ///
    /// TODO:    Can remove verifyAmount() since we check it in verifyWithdrawer()
    ///          which is called directly before this function in the same tx.
    ///          Before doing this, need to verify it is in fact ALWAYS called
    ///          before this function.
    function updateTokenUponWithdrawal(
        bytes32 typeId,
        bytes32 tokenId,
        uint valueToWithdraw,
        uint pricePerShare,
        uint shares,
        uint unrealizedYield
    )
        external
        notDeprecated
        onlyPortfolioOrOpportunityManager(typeId)
        verifyAmount(typeId, valueToWithdraw)
    {

      uint shareSupply = _storage.getShareSupply(typeId);
      uint sharesToBurn = calculateSharesToBurn(typeId, valueToWithdraw, shares, pricePerShare);

      updateTokenUponWithdrawal2(
          typeId,
          tokenId,
          unrealizedYield,
          shareSupply,
          shares,
          sharesToBurn
      );

    }


    /** ----------------- ONLY ADMIN MUTATORS ----------------- **/


    /// @notice  Sets the deprecated flag of the contract
    ///
    /// @dev     Used when upgrading a contract
    ///
    /// @param   value - true to deprecate, false to un-deprecate
    function setDeprecated(bool value) external onlyAdmin {

        deprecated = value;

    }


  /******************* INTERNAL FUNCTIONS *******************/


  /// @notice  Part 2 of 2 for creating a token
  function createToken2(
      bytes32 typeId,
      bytes32 tokenId,
      uint value,
      uint numOfShares
  )
      internal
  {

    StorageWrapper(_storage.getContractAddress(STORAGE_WRAPPER_CONTRACT)).setTokenCapital(typeId, tokenId, value);
    StorageWrapper(_storage.getContractAddress(STORAGE_WRAPPER_CONTRACT)).setTokenShares(typeId, tokenId, numOfShares);

    uint newShareSupply = SafeMath.add(_storage.getShareSupply(typeId), numOfShares); // check for overflow
    StorageWrapper(_storage.getContractAddress(STORAGE_WRAPPER_CONTRACT)).setShareSupply(typeId, newShareSupply);

  }


  function calculatePremiumValue(
    bytes32 typeId,
    uint value,
    uint pricePerShare
  )
    internal
    returns (uint)
  {

    uint raised = _storage.getRaised(_storage.getPrincipalAddress(typeId));

    uint numOfShares = value * raised / pricePerShare;
    // below line won't underflow since pricePerShare is partly made up of BASE_PRICE_IN_WEI * ON_CHAIN_PRECISION
    uint premiumValue = (numOfShares * (pricePerShare - (BASE_PRICE_IN_WEI * ON_CHAIN_PRECISION))) / raised;

    uint newRealizedYield = _storage.getRealizedYield(typeId) + premiumValue;
    StorageWrapper(_storage.getContractAddress(STORAGE_WRAPPER_CONTRACT)).setRealizedYield(typeId, newRealizedYield);

    return numOfShares;

  }


  /// @notice  Part 3 of 3 for increasing a token's capital
   function increaseTokenCapital3(
        bytes32 typeId,
        bytes32 tokenId,
        uint numOfShares
    )
        internal
    {

      uint tokenShares = _storage.getTokenShares(typeId, tokenId);
      uint newTokenShares = tokenShares + numOfShares;
      StorageWrapper(_storage.getContractAddress(STORAGE_WRAPPER_CONTRACT)).setTokenShares(typeId, tokenId, newTokenShares);

      uint newShareSupply = SafeMath.add(_storage.getShareSupply(typeId), numOfShares); // check for overflow
      StorageWrapper(_storage.getContractAddress(STORAGE_WRAPPER_CONTRACT)).setShareSupply(typeId, newShareSupply);

    }


    /// @notice  Part 2 of 2 for withdrawing from a token
    function updateTokenUponWithdrawal2(
        bytes32 typeId,
        bytes32 tokenId,
        uint unrealizedYield,
        uint shareSupply,
        uint shares,
        uint sharesToBurn
    )
      internal
    {

      uint realizedYield = _storage.getRealizedYield(typeId);
      uint withdrawnYield = _storage.getWithdrawnYield(typeId);
      uint totalYield = getTotalYield(unrealizedYield, realizedYield, withdrawnYield);

      uint percentageOfShares = bankersRounding(sharesToBurn * ON_CHAIN_PRECISION, shareSupply);

      uint premiumToBurn = totalYield * percentageOfShares / ON_CHAIN_PRECISION;

      updateYieldTrackers(typeId, realizedYield, premiumToBurn, withdrawnYield);
      updateShares(typeId, shareSupply, shares, sharesToBurn, tokenId);

    }

    /// @notice   Helper function of updateTokenUponWithdrawal(), updates the
    ///           respective values of the tokens portfolios pool state
    ///
    /// TODO:     Same functionality as a function in NAVCalculator, DRY
    function updateYieldTrackers(
        bytes32 typeId,
        uint realizedYield,
        uint premiumToBurn,
        uint withdrawnYield
    )
        internal
    {

      if (realizedYield < premiumToBurn) {

          uint difference = premiumToBurn - realizedYield; // can't underflow due to if() ^
          realizedYield = realizedYield - (premiumToBurn - difference); // or 0
          StorageWrapper(_storage.getContractAddress(STORAGE_WRAPPER_CONTRACT)).setRealizedYield(typeId, realizedYield); // or == 0
          withdrawnYield += difference;
          StorageWrapper(_storage.getContractAddress(STORAGE_WRAPPER_CONTRACT)).setWithdrawnYield(typeId, withdrawnYield);

      } else {

          realizedYield -= premiumToBurn; // can't underflow due to if() ^
          StorageWrapper(_storage.getContractAddress(STORAGE_WRAPPER_CONTRACT)).setRealizedYield(typeId, realizedYield);

      }

    }


    /// @notice  Helper function for updateTokenUponWithdrawal()
    ///
    /// @dev     Will 'reset' the portfolios PPS is it realizes there are currently
    ///          no tokens/shares in it anymore.
    function updateShares(
        bytes32 typeId,
        uint shareSupply,
        uint shares,
        uint sharesToBurn,
        bytes32 tokenId
    )
        internal
    {

      // we always check we aren't burning more shares than a token owns including
      // consideration for rounding/ceilings so this shouldn't ever underflow.
      // but add safemath anyway for now. (audit suggestion)
      // shareSupply -= sharesToBurn;
      shareSupply = SafeMath.sub(shareSupply, sharesToBurn);
      StorageWrapper(_storage.getContractAddress(STORAGE_WRAPPER_CONTRACT)).setShareSupply(typeId, shareSupply);

      if (shareSupply == 0) {
          StorageWrapper(_storage.getContractAddress(STORAGE_WRAPPER_CONTRACT)).setRealizedYield(typeId, 0);
          StorageWrapper(_storage.getContractAddress(STORAGE_WRAPPER_CONTRACT)).setWithdrawnYield(typeId, 0);
      }

      // we mitigated underflow earlier on for this but check again anyway for now (audit suggestion)
      uint numOfShares = SafeMath.sub(shares, sharesToBurn); // shares - sharesToBurn
      StorageWrapper(_storage.getContractAddress(STORAGE_WRAPPER_CONTRACT)).setTokenShares(typeId, tokenId, numOfShares);

    }


    /** ----------------- PURE ACCESSORS ----------------- **/


    /// @notice  Helper function for updateTokenUponWithdrawal() that finds the
    ///          number of shares to burn based on the amount being withdrawn
    function calculateSharesToBurn(
      bytes32 typeId,
      uint valueToWithdraw,
      uint shares,
      uint pricePerShare
    )
      internal
      view
      returns (uint)
    {

      uint raised = _storage.getRaised(_storage.getPrincipalAddress(typeId));
      uint percentageOfValue = (valueToWithdraw * raised) / ((shares * pricePerShare) / raised);
      uint sharesToBurn = calculateCeiling((shares * percentageOfValue / raised), 10);

      // small probability, but finding the ceiling on the shares themselves and not
      // on the percentage could lead to burning more shares then we have so we
      // add this check
      if (sharesToBurn > shares) {

         sharesToBurn = shares;

      }

      return sharesToBurn;

    }


    /// @notice  Find the ceiling of the number
    ///
    /// @return  The ceiling of the number
    function calculateCeiling(uint a, uint m) internal pure returns (uint) {
       return ((a + m - 1) / m) * m;
   }


   /// @notice  Impl. of bankers ronding that is used to divide and round the result
   ///          (AKA round-half-to-even)
   ///
   ///          Bankers Rounding is an algorithm for rounding quantities to integers,
   ///          in which numbers which are equidistant from the two nearest integers
   ///          are rounded to the nearest even integer.
   ///
   ///          Thus, 0.5 rounds down to 0; 1.5 rounds up to 2.
   ///          Other decimal fractions round as you would expect--0.4 to 0, 0.6 to 1,
   ///          1.4 to 1, 1.6 to 2, etc. Only x.5 numbers get the "special" treatment.
   ///
   /// @param   a - what to divide
   /// @param   b - divide by this number
   ///
   /// NOTE:    This function (bankersRounding(uint, uint)) is subject to:
   ///
   ///           The MIT License (MIT)
   ///
   ///           Copyright (c) 2016 Smart Contract Solutions, Inc.
   ///
   ///           Permission is hereby granted, free of charge, to any person obtaining
   ///           a copy of this software and associated documentation files (the
   ///          "Software"), to deal in the Software without restriction, including
   ///           without limitation the rights to use, copy, modify, merge, publish,
   ///           distribute, sublicense, and/or sell copies of the Software, and to
   ///           permit persons to whom the Software is furnished to do so, subject to
   ///           the following conditions:
   ///
   ///           The above copyright notice and this permission notice shall be included
   ///           in all copies or substantial portions of the Software.
   ///
   ///           THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
   ///           OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
   ///           MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
   ///           IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
   ///           CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
   ///           TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
   ///           SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
   function bankersRounding(uint256 a, uint256 b) internal pure returns (uint256) {

      uint256 halfB = 0;

      if ((b % 2) == 1) {

         halfB = (b / 2) + 1;

      } else {

         halfB = b / 2;

      }

      bool roundUp = ((a % b) >= halfB);
      bool isCenter = ((a % b) == (b / 2));
      bool isDownEven = (((a / b) % 2) == 0);

      if (isCenter) {

          roundUp = !isDownEven;

      }

      // round
      if (roundUp) {

        return ((a / b) + 1);

      } else {

        return (a / b);

      }

    }


    /// TODO: Remove this, repetitive function in NAVCalculator to
    function getTotalYield(
      uint unrealizedYield,
      uint realizedYield,
      uint withdrawnYield
    )
      internal
      pure
      returns (uint)
    {

      // withdrawnYield can't be bigger than unrealizedYield + realizedYield since it's the
      // unrealized yield we already added to realizedYield, it's there to make sure we
      // don't double count it, but check underflow anyway for now (audit suggestion)
      // unrealizedYield + realizedYield - withdrawnYield
      uint totalYield = SafeMath.sub((unrealizedYield + realizedYield), withdrawnYield);

      return totalYield;

    }

}
