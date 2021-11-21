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


// interal dependencies
import './RoboErc20.sol';
import './lib/SafeERC20.sol';


/// @notice  Standard contract for USDT RoboTokens of the RAY Protocol. Technically,
///          it works for any token that is non-ERC20 standard in the same manner
///          as Tether.
///
/// Author:   Devan Purhar
/// Version:  1.0.0
contract RoboSafeErc20 is RoboErc20 {
  using SafeERC20 for IERC20;


  /********************* PUBLIC FUNCTIONS **********************/


  /// @notice  Serves as the constructor of this contract. No constructors
  //           allowed in this proxy pattern.
  ///
  /// @param   _rayStorage - The Storage contracts address
  function initialize(
    address _rayStorage,
    address _underlying,
    string memory name,
    string memory symbol,
    uint8 decimals
  )
    public
    initializer
  {

    // input validated in parent

    // call initializer in parent contract
    RoboErc20.initialize(_rayStorage, _underlying, name, symbol, decimals);

  }


  /** ----------------- OVERRIDDEN ROBOERC20 FUNCTIONS ----------------- **/


  /// @dev  Only RAYv2 can transfer funds to itself through this function
  function transferFundsToCore(uint amountToTransfer) external onlyRAYv2 {

    // msg.sender is always our RAYv2 contract due to the function modifier
    transferOut(msg.sender, amountToTransfer);

  }


  /// @dev  Anyone can call this function, forcing another users funds to be withdrawn
  ///       which would be bad long-term, but in context of the shutdown doesn't matter.
  ///
  ///       The user whose value is being withdrawn will always receive the value, so funds
  ///       aren't being stolen through this.
  function forceRedeem(address user) external /*onlyGovernance*/ {

    uint availableUnderlying = getLocalBalance();

    // This always calls a function that uses re-entrancy guard, done before any other
    // external system contract calls
    uint amountRedeemed = forceRedeemAction(user, availableUnderlying);

    // Now transfer funds received from OM to the user.
    // External system untrusted call.
    // Uses call.value() and doesn't protect from re-entrancy. Using this over
    // transfer() in light of Istanbul changing pricing for opcodes.
    // https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/
    // This follows the checks-effects-interactions pattern.
    transferOut(user, amountRedeemed);

  }


  /********************* INTERNAL FUNCTIONS **********************/


  /** ----------------- OVERRIDDEN ROBOERC20 FUNCTIONS ----------------- **/


  /// @notice Overridden to add support for non-standard ERC20 token Tether
  ///         which doesn't return a bool.
  ///
  /// @dev  Be aware that this is an external system call, limit dangerous re-entrancy
  function transferIn(address sender, uint amountToTransfer) internal {

    // Calls an external system contract - the underlying token contract. We generally
    // trust these, but want to minimize that trust where possible.
    // Supports non-standard ERC20's such as USDT which don't return bool
    // This handles making sure the call succeeded, and reverts on failure.
    IERC20(underlying).safeTransferFrom(sender, address(this), amountToTransfer);

  }


  /// @notice Overridden to add support for non-standard ERC20 token Tether
  ///         which doesn't return a bool.
  ///
  /// @dev  Be aware that this is an external system call, limit dangerous re-entrancy
  function transferOut(address receiver, uint amountToTransfer) internal {

    // Calls an external system contract - the underlying token contract. We generally
    // trust these, but want to minimize that trust where possible.
    // Supports non-standard ERC20's such as USDT which don't return bool
    // This handles making sure the call succeeded, and reverts on failure.
    IERC20(underlying).safeTransfer(receiver, amountToTransfer);

  }

}
