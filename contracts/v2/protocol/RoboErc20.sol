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


// external dependencies
import "./openzeppelin/contracts-ethereum-package/token/ERC20/IERC20.sol";

// interal dependencies
import './RoboToken.sol';


/// @notice  Standard contract for ERC20 RoboTokens of the RAY Protocol
///
/// Author:   Devan Purhar
/// Version:  1.0.0
contract RoboErc20 is RoboToken {


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
    initializer
    public
  {

    RoboToken.initialize(_rayStorage, _underlying, name, symbol, decimals);

  }


  /** ----------------- ONLY RAYV2 / OVERRIDDEN ABSTRACT FUNCTIONS ----------------- **/


  /// @dev  Only RAYv2 can transfer funds to itself through this function
  function transferFundsToCore(uint amountToTransfer) external onlyRAYv2 {

    require(
      IERC20(underlying).transfer(msg.sender, amountToTransfer),
      "#RoboErc20 transferFundsToCore(): Transfer of ERC20 Token failed"
    );

  }


  /** ----------------- PERMISSIONLESS USER ENTRYPOINTS ----------------- **/


  /// @notice   Mint RoboTokens through depositing the underlying asset.
  ///
  /// @return  The amount of RoboTokens minted
  function mint(uint mintAmount) external returns (uint) {

    transferIn(msg.sender, mintAmount);

    uint availableUnderlying = getLocalBalance().sub(mintAmount);

    uint tokensMinted = mintAction(mintAmount, availableUnderlying);

    return tokensMinted;

  }


  /// @notice   Burns the amount of RoboTokens requested in exchange for the equal underlying.
  ///
  /// @param    redeemTokens - The amount of RoboTokens to burn.
  ///
  /// @return   the amount of underlying received
  function redeem(uint redeemTokens) external returns (uint) {

    uint availableUnderlying = getLocalBalance();

    uint amountRedeemed = redeemAction(redeemTokens, availableUnderlying);

    transferOut(msg.sender, amountRedeemed);

    return amountRedeemed;

  }


  /// @notice  Burns the amount of RoboTokens equal to the requested underlying.
  ///
  /// @dev     Could return the amount of underlying received, though it's currently
  ///          always the amount requested.
  ///
  ///          Transfers out the requested amount or fails the transaction.
  ///
  /// @param  redeemAmount - The amount of the underlying token to withdraw in the
  ///                        smallest units in-kind.
  function redeemUnderlying(uint redeemAmount) external {

    uint availableUnderlying = getLocalBalance();

    redeemUnderlyingAction(redeemAmount, availableUnderlying);

    transferOut(msg.sender, redeemAmount);

  }


  /// @notice  Uses the 'burn' NAV as  the exchange rate, to return the value claimable
  ///          at this time. Reallistically, the underlying value is likely a bit
  ///          more however if a user were to redeem, they wouldn't have access to that
  ///          value yet.
  ///
  /// @return  The total claimable value in underlying for the entered address
  function balanceOfUnderlying(address owner) external returns (uint) {

    uint availableUnderlying = getLocalBalance();

    return _balanceOfUnderlying(owner, availableUnderlying);

  }


  /// @return  The current RoboToken price.
  function exchangeRateCurrent() external returns (uint) {

    uint availableUnderlying = getLocalBalance();

    return _exchangeRateType(availableUnderlying, IRAYv2.ExchangeRates.CURRENT);

  }


  /// @return  The minting RoboToken price.
  function exchangeRateMint() external returns (uint) {

    uint availableUnderlying = getLocalBalance();

    return _exchangeRateType(availableUnderlying, IRAYv2.ExchangeRates.MINT);

  }


  /// @return  The burning RoboToken price.
  function exchangeRateBurn() external returns (uint) {

    uint availableUnderlying = getLocalBalance();

    return _exchangeRateType(availableUnderlying, IRAYv2.ExchangeRates.BURN);

  }


  /********************* INTERNAL FUNCTIONS **********************/


  /** ----------------- OVERRIDDEN ABSTRACT FUNCTIONS ----------------- **/


  function transferIn(address sender, uint amountToTransfer) internal {

    require(
      IERC20(underlying).transferFrom(sender, address(this), amountToTransfer),
      "#RoboErc20 transferIn(): TransferFrom of ERC20 Token failed"
    );

  }


  function transferOut(address receiver, uint amountToTransfer) internal {

    require(
      IERC20(underlying).transfer(receiver, amountToTransfer),
      "#RoboErc20 transferOut(): Transfer of ERC20 Token failed"
    );

  }


  function getLocalBalance() internal view returns (uint) {

    uint localBalance = IERC20(underlying).balanceOf(address(this));

    return localBalance;

  }

}
