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
import "./openzeppelin/contracts-ethereum-package/token/ERC20/ERC20.sol";
import "./openzeppelin/contracts-ethereum-package/token/ERC20/ERC20Detailed.sol";
import "./openzeppelin/contracts-ethereum-package/token/ERC20/IERC20.sol";

// internal dependencies
import './interfaces/IRAYv2.sol';
import './interfaces/IStorage.sol';


/// @notice  Standard contract for RoboTokens of the RAY Protocol
///
/// Author:   Devan Purhar
/// Version:  1.0.0
contract RoboToken is ERC20, ERC20Detailed  {


  /*************** STORAGE VARIABLE DECLARATIONS **************/


  bytes32 internal constant RAY_V2_CONTRACT = keccak256("RAYv2Contract");

  address public rayStorage;
  address public underlying;


  /*************** MODIFIER DECLARATIONS **************/


  /// @notice  Requires the caller is the RAYv2 contract
  modifier onlyRAYv2()
  {

    require(
      msg.sender == IStorage(rayStorage).getContractAddress(RAY_V2_CONTRACT),
      "#RAYv2 onlyRAYv2 Modifier: Only RAYv2 can call this"
    );

    _;

  }


  /////////////////////// FUNCTION DECLARATIONS BEGIN ///////////////////////


  /********************* PUBLIC FUNCTIONS **********************/


  /// @notice  Serves as the constructor of this contract. No constructors
  ///          allowed in this proxy pattern implementation.
  ///
  /// @dev     'initializer' modifier only lets this function be called once, to
  ///           mimic the behaviour of a true 'constructor'.
  ///
  /// @param   _rayStorage - The RAY Storage contract address
  /// @param   name - The name of the token
  /// @param   symbol - The symbol/ticker of the token
  /// @param   decimals - The decimals used by the token for representation
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

    ERC20Detailed.initialize(name, symbol, decimals);

    require(
      _rayStorage != address(0) && _underlying != address(0),
      "#RoboToken intialize: RAY storage or underlying cannot be set to the null address."
    );

    rayStorage = _rayStorage;
    underlying = _underlying;
  }


  /********************* INTERNAL FUNCTIONS **********************/


  /// @return  The amount of RoboTokens minted
  function mintAction(uint mintAmount, uint availableUnderlying) internal returns (uint) {

    address ray = IStorage(rayStorage).getContractAddress(RAY_V2_CONTRACT);

    uint tokensToMint = IRAYv2(ray).calculateTokensToMint(underlying, msg.sender, mintAmount, availableUnderlying);

    super._mint(msg.sender, tokensToMint);

    return tokensToMint;

  }


  function redeemAction(uint redeemTokens, uint availableUnderlying) internal returns (uint) {

    address ray = IStorage(rayStorage).getContractAddress(RAY_V2_CONTRACT);

    uint userTotalTokens = balanceOf(msg.sender);

    uint amountToRedeem = IRAYv2(ray).redeemRoboTokens(underlying, redeemTokens, availableUnderlying, msg.sender, userTotalTokens);

    super._burn(msg.sender, redeemTokens);

    return amountToRedeem;

  }


  function redeemUnderlyingAction(uint redeemAmount, uint availableUnderlying) internal {

    address ray = IStorage(rayStorage).getContractAddress(RAY_V2_CONTRACT);

    uint userTotalTokens = balanceOf(msg.sender);

    uint redeemTokens = IRAYv2(ray).redeemUnderlyingRoboTokens(underlying, redeemAmount, availableUnderlying, msg.sender, userTotalTokens);

    super._burn(msg.sender, redeemTokens);

  }


  function _balanceOfUnderlying(address owner, uint availableUnderlying) internal returns (uint) {

    address ray = IStorage(rayStorage).getContractAddress(RAY_V2_CONTRACT);

    uint tokens = balanceOf(owner);
    uint nav;
    uint raised;

    (nav, raised) = IRAYv2(ray).getPortfolioNAVType(underlying, availableUnderlying, IRAYv2.ExchangeRates.BURN);

    uint balance = nav.mul(tokens).div(raised);

    return balance;

  }


  function _exchangeRateType(uint availableUnderlying, IRAYv2.ExchangeRates rateType) internal returns (uint) {

    address ray = IStorage(rayStorage).getContractAddress(RAY_V2_CONTRACT);

    uint nav;

    (nav, ) = IRAYv2(ray).getPortfolioNAVType(underlying, availableUnderlying, rateType);

    return nav;

  }


  /** ----------------- ABSTRACT FUNCTIONS ----------------- **/


  function transferFundsToCore(uint amountToTransfer) external;


  function transferIn(address sender, uint amountToTransfer) internal;


  function transferOut(address receiver, uint amountToTransfer) internal;


  function getLocalBalance() internal view returns (uint);


}
