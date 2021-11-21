/**

    The software and documentation available in this repository (the "Software") is
    protected by copyright law and accessible pursuant to the license set forth below.

    Copyright © 2020 Staked Securely, Inc. All rights reserved.

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

pragma solidity 0.5.11;

interface IRAYv2 {

  /* ------- USED IN ROBOTOKENS ------- */


  enum ExchangeRates { MINT, BURN, CURRENT }


  function calculateTokensToMint(
    address underlying,
    address user, // only used in event
    uint amountDeposited,
    uint availableUnderlying
  )
    external
    returns (uint);


  function redeemRoboTokens(
    address underlying,
    uint redeemTokens,
    uint availableUnderlying,
    address user, // only used in event
    uint usersTotalTokens // only used in event
  )
    external
    returns (uint);


  function redeemUnderlyingRoboTokens(
    address underlying,
    uint amountToRedeem,
    uint availableUnderlying,
    address user, // only used in event
    uint usersTotalTokens
  )
    external
    returns (uint);


  function getPortfolioNAVType(
    address underlying,
    uint availableUnderlying,
    ExchangeRates rateType
  )
    external
    returns (uint, uint);


    /* ------- USED IN ADMIN_TWO ------- */

  /// @notice  Adds or removes RoboToken status of an address
  function setRoboToken(address roboToken, bool value) external;


  /// @notice  Adds RoboToken status of an address and sets up all required data
  function initRoboToken(address roboToken, bytes32 portfolioId) external;


  /// @notice  Adds RoboToken status of an address and sets up all required data
  function setupAsset(address underlying, uint coinStandard, uint raised) external;


  /// @notice  Sets a new value for the period length of cahced NAV
  function setPeriodLength(uint newPeriodLength) external;


}
