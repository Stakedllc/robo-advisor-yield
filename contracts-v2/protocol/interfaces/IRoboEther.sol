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


/// @title   IRoboEther
///
/// @notice  Interface of the RoboEther contract, which is used for RAY tokens that
///          represent Ether asset positions.
///
/// @dev     VERSION: 1.0
///          AUTHOR: Devan Purhar
interface IRoboEther {


  /// @notice  Deposit the underlying asset, in return mint and receive back RAY
  ///          tokens.
  ///
  /// @dev     Must send the Ether being deposited in the transaction, as the 'value'
  ///          field.
  ///
  /// @return  The amount of RAY tokens minted and sent to the sender.
  function mint() external payable returns (uint);


  /// @notice  Withdraw the underlying asset, in return redeem and burn RAY
  ///          tokens.
  ///
  /// @dev     Reverts the transaction on any failure, including not withdrawing
  ///          the amount of underlying requested.
  ///
  /// @param   redeemTokens - The amount of RAY tokens to redeem.
  ///
  /// @return  The amount of underlying withdrawn.
  function redeem(uint redeemTokens) external returns (uint);


  /// @notice  Withdraw the underlying asset, in return redeem and burn RAY
  ///          tokens.
  ///
  /// @dev     Reverts the transaction on any failure, including not withdrawing
  ///          the amount of underlying requested.
  ///
  /// @param   redeemAmount - The amount of underlying to withdraw.
  function redeemUnderlying(uint redeemAmount) external;


  /// @notice  Get the underlying asset's contract address of the RoboEther.
  ///
  /// @dev     Within the RAY system, the Ether address is represented as the canonical
  ///          WETH contract.
  ///
  /// @return  The underlying asset's contract address.
  function underlying() external view returns (address);


  /// @notice  Get the realized balance of the RAY tokens owned by an address
  ///          represented in the underlying asset.
  ///
  /// @dev     Realized balance means the balance the user has claim to at this
  ///          point in time. This function uses the 'burn' exchange rate.
  ///
  /// @param   owner - The ETH address of the user to look-up.
  ///
  /// @return  The balance owned by the user denominated in the underlying asset.
  function balanceOfUnderlying(address owner) external returns (uint);


  /// @notice  Get the current exchange rate between the RAY tokens and the underlying.
  ///
  /// @dev     This is the current exchange rate, but not all of it may be realized yet.
  ///
  /// @return  The current exchange rate between the RAY tokens and the underlying.
  function exchangeRateCurrent() external returns (uint);


  /// @notice  Get the mint exchange rate between the RAY tokens and the underlying.
  ///
  /// @dev     This is the exchange rate used to price deposits into the system.
  ///
  /// @return  The mint exchange rate between the RAY tokens and the underlying.
  function exchangeRateMint() external returns (uint);


  /// @notice  Get the burn exchange rate between the RAY tokens and the underlying.
  ///
  /// @dev     This is the exchange rate used to price withdrawals from the system.
  ///
  /// @return  The burn exchange rate between the RAY tokens and the underlying.
  function exchangeRateBurn() external returns (uint);


}
