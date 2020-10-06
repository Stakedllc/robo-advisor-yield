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
///          represent Ether asset positions. RoboEther are ERC-20 standard compliant.
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


  // --------------------- STANDARD ERC-20 INTERFACE --------------------- //


  /// @dev Returns the amount of tokens in existence.
  function totalSupply() external view returns (uint256);


  /// @dev Returns the amount of tokens owned by `account`.
  function balanceOf(address account) external view returns (uint256);


  /// @dev Moves `amount` tokens from the caller's account to `recipient`.
  ///
  /// Returns a boolean value indicating whether the operation succeeded.
  ///
  /// Emits a {Transfer} event.
  function transfer(address recipient, uint256 amount) external returns (bool);


  /// @dev Returns the remaining number of tokens that `spender` will be
  /// allowed to spend on behalf of `owner` through {transferFrom}. This is
  /// zero by default.
  ///
  /// This value changes when {approve} or {transferFrom} are called.
  function allowance(address owner, address spender) external view returns (uint256);


  /// @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
  ///
  /// Returns a boolean value indicating whether the operation succeeded.
  ///
  /// IMPORTANT: Beware that changing an allowance with this method brings the risk
  /// that someone may use both the old and the new allowance by unfortunate
  /// transaction ordering. One possible solution to mitigate this race
  /// condition is to first reduce the spender's allowance to 0 and set the
  /// desired value afterwards:
  /// https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
  ///
  /// Emits an {Approval} event.
  function approve(address spender, uint256 amount) external returns (bool);


  /// @dev Moves `amount` tokens from `sender` to `recipient` using the
  /// allowance mechanism. `amount` is then deducted from the caller's
  /// allowance.
  ///
  /// Returns a boolean value indicating whether the operation succeeded.
  ///
  /// Emits a {Transfer} event.
  function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);


  /// @dev Emitted when `value` tokens are moved from one account (`from`) to
  /// another (`to`).
  ///
  /// Note that `value` may be zero.
  event Transfer(address indexed from, address indexed to, uint256 value);


  /// @dev Emitted when the allowance of a `spender` for an `owner` is set by
  /// a call to {approve}. `value` is the new allowance.
  ///
  event Approval(address indexed owner, address indexed spender, uint256 value);


}
