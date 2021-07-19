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

/// @dev  dYdX uses pragma experimental ABIEncoderV2, to support their protocol we
///       need to use it in this contract, it's use is isolated to this contract
///       (but other contracts call this). Their methods to lend/withdraw accept
///       an array of structs.
pragma experimental ABIEncoderV2;


// external dependency
import "../../../external/dydx/SoloMargin.sol";
import "../../../external/dydx/Account.sol";
import "../../../external/dydx/Actions.sol";
import { Types } from "../../../external/dydx/Types.sol";
import "../openzeppelin/ERC20/IERC20.sol";
import "../../../external/WETH9.sol";

// internal dependency
import "../../interfaces/Opportunity.sol";
import "../../interfaces/MarketByNumber.sol";

import "../Storage.sol";


/// @notice  Communicating Proxy to the dYdX Protocol
///
/// @dev     Follows the standard 'Opportunity' interface
///
/// Author:  Devan Purhar
/// Version: 1.0.0

contract DydxOpportunity is Opportunity, MarketByNumber {


  /*************** STORAGE VARIABLE DECLARATIONS **************/


  // contracts used
  bytes32 internal constant ADMIN_CONTRACT = keccak256("AdminContract");
  bytes32 internal constant OPPORTUNITY_MANAGER_CONTRACT = keccak256("OpportunityManagerContract");
  bytes32 internal constant WETH_TOKEN_CONTRACT = keccak256("WETHTokenContract");

  Storage public _storage;
  mapping(address => uint[2]) public markets;
  address public dydxMarket;


  /*************** MODIFIER DECLARATIONS **************/


  /// @notice  Checks the caller is our Governance Wallet
  ///
  /// @dev     To be removed once fallbacks are
  modifier onlyGovernance()
  {
      require(
          msg.sender == _storage.getGovernanceWallet(),
          "#DydxImpl onlyGovernance Modifier: Only Governance can call this"
      );

      _;
  }


  /// @notice  Checks the caller is our Admin contract
  modifier onlyAdmin()
  {
      require(
          msg.sender == _storage.getContractAddress(ADMIN_CONTRACT),
          "#DydxImpl onlyAdmin Modifier: Only Admin can call this"
      );

      _;
  }


  /// @notice  Checks the caller is our OpportunityManager contract
  modifier onlyOpportunityManager()
  {
      require(
          msg.sender == _storage.getContractAddress(OPPORTUNITY_MANAGER_CONTRACT),
          "#DydxImpl onlyOpportunityManager Modifier: Only OpportunityManager can call this"
      );

      _;
  }


  /////////////////////// FUNCTION DECLARATIONS BEGIN ///////////////////////

  /******************* PUBLIC FUNCTIONS *******************/


  /// @notice  Sets Storage instance and inits the coins supported by the Opp.
  ///
  /// @dev     The principalTokens and ids[] need to correlate by index
  ///
  ///          IDs: 0 == ETH, 1 == DAI, 2 == USDC
  ///
  ///          Ex. principalTokens[0] == DAI Address, primaryIds[0] == 1,
  ///              secondaryIds[0] == 1
  ///
  /// @param   __storage - The Storage contracts address
  /// @param   principalTokens - The coin addresses to add support for
  /// @param   primaryIds - dydx term, the id is tied to a coin
  /// @param   secondaryIds - dydx term, the id is tied to a coin
  constructor(
    address __storage,
    address _dydxMarket,
    address[] memory principalTokens,
    uint[] memory primaryIds,
    uint[] memory secondaryIds
  )
    public
  {

    _storage = Storage(__storage);
    dydxMarket = _dydxMarket;

    _addPrincipalTokens(principalTokens, primaryIds, secondaryIds);

  }


  /// @notice  Fallback function to receive Ether
  ///
  /// @dev     Required to receive Ether from Dydx upon withdraws
  function() external payable {

  }


  /** --------------- OpportunityManager Entrypoints ----------------- **/


  /// @notice  The entrypoint for OpportunityManager to lend
  ///
  /// @param    principalToken - The coin address to lend
  /// @param    value - The amount to lend
  /// @param    isERC20 - true if principalToken is an ERC20, false if not
  function supply(
    address principalToken,
    uint value,
    bool isERC20
  )
    external
    onlyOpportunityManager
    payable
  {

    if (isERC20) {

      require(
        IERC20(principalToken).transferFrom(msg.sender, address(this), value),
        "#DydxImpl supply(): TransferFrom of ERC20 Token failed"
      );

    } else {

      wrapETH(msg.value); // wrap all ETH sent in

    }

    invest(principalToken, value);

  }


  /// @notice  The entrypoint for OpportunityManager to withdraw
  ///
  /// @param    principalToken - The coin address to withdraw
  /// @param    beneficiary - The address to send funds too - always OpportunityManager for now
  /// @param    valueToWithdraw - The amount to withdraw
  /// @param    isERC20 - true if principalToken is an ERC20, false if not
  function withdraw(
    address principalToken,
    address beneficiary,
    uint valueToWithdraw,
    bool isERC20
  )
    external
    onlyOpportunityManager
  {

    withdraw(principalToken, valueToWithdraw);

    if (isERC20) {

      require(
        IERC20(principalToken).transfer(beneficiary, valueToWithdraw),
        "DydxImpl withdraw(): Transfer of ERC20 Token failed"
      );

    } else {

      unwrapETH(valueToWithdraw); // unwrap weth
      beneficiary.transfer(valueToWithdraw);

    }

  }


  /** ----------------- ONLY ADMIN MUTATORS ----------------- **/


  /// @notice  Used to add coins support to this Opportunities configuration
  ///
  /// @dev      IDs: 0 == ETH, 1 == DAI, 2 == USDC
  ///
  /// @param   principalTokens - The coin contract addresses
  /// @param   primaryIds - dydx term, the id is tied to a coin
  /// @param   secondaryIds - dydx term, the id is tied to a coin
  function addPrincipalTokens(
    address[] memory principalTokens,
    uint[] memory primaryIds,
    uint[] memory secondaryIds
  )
    public // not using external b/c use memory to pass in array
    onlyAdmin
  {

    _addPrincipalTokens(
      principalTokens,
      primaryIds,
      secondaryIds
    );

  }



  /// @notice  Set the single address of the Dydx contract
  ///
  /// @param   newDydxMarket - The new Dydx contract
  function setDydxContract(address newDydxMarket) external onlyAdmin {

    dydxMarket = newDydxMarket;

  }


  /** ----------------- VIEW ACCESSORS ----------------- **/


  /// @notice  Get the current balance we have in the Opportunity (principal + interest generated)
  ///
  /// @param   principalToken - The coins address
  ///
  /// @return  The total balance in the smallest units of the coin
  function getBalance(address principalToken) external view returns(uint) {

      uint marketId = markets[principalToken][0];

      Account.Info memory account = Account.Info(
        address(this),
        0
      );

      address[] memory addresses;
      Types.Par[] memory principalAmounts;
      Types.Wei[] memory totalBalances;

      (addresses, principalAmounts, totalBalances) = SoloMargin(dydxMarket).getAccountBalances(account);

      return totalBalances[marketId].value;

  }


  /*************** INTERNAL FUNCTIONS **************/

  /** ----------------- OPPORTUNITY LEND/WITHDRAW PROXY FUNCTIONS ----------------- **/


  /// @notice  The custom lending impl. for Dydx
  ///
  /// @param   principalToken - The address of the coin to lend
  /// @param   value - The amount of value to lend in-kind smallest units
  function invest
  (
      address principalToken,
      uint value
  )
      internal
  {

    uint primaryMarketId = markets[principalToken][0];
    uint secondaryMarketId = markets[principalToken][1];

    // give allowance to Dydx to use our ERC20 balance
    require(
      IERC20(principalToken).approve(dydxMarket, value),
      "DydxImpl invest(): Approval of ERC20 Token failed"
    );

    Account.Info memory account = Account.Info(
      address(this),
      0
    );

    Account.Info[] memory accounts = new Account.Info[](1);
    accounts[0] = account;

    Types.AssetAmount memory assetAmount = Types.AssetAmount(
      true,
      Types.AssetDenomination.Wei,
      Types.AssetReference.Delta,
      value
    );

    bytes memory emptyBytes;

    Actions.ActionArgs memory action = Actions.ActionArgs(
      Actions.ActionType.Deposit,
      0,
      assetAmount,
      primaryMarketId,
      secondaryMarketId,
      address(this),
      0,
      emptyBytes
    );

    Actions.ActionArgs[] memory actions = new Actions.ActionArgs[](1);
    actions[0] = action;

    SoloMargin(dydxMarket).operate(accounts, actions);

  }


  /// @notice  Custom impl. to withdraw from Dydx
  ///
  /// @param   principalToken - The address of the coin to withdraw
  /// @param   amountToWithdraw - The amount we want to withdraw in-kind smallest units
  function withdraw
  (
      address principalToken,
      uint amountToWithdraw
  )
      internal
  {

    uint primaryMarketId = markets[principalToken][0];
    uint secondaryMarketId = markets[principalToken][1];

    Account.Info memory account = Account.Info(
      address(this),
      0
    );

    Account.Info[] memory accounts = new Account.Info[](1);
    accounts[0] = account;

    Types.AssetAmount memory assetAmount = Types.AssetAmount(
      false,
      Types.AssetDenomination.Wei,
      Types.AssetReference.Delta,
      amountToWithdraw
    );

    bytes memory emptyBytes;

    Actions.ActionArgs memory action = Actions.ActionArgs(
      Actions.ActionType.Withdraw,
      0,
      assetAmount,
      primaryMarketId,
      secondaryMarketId,
      address(this),
      0,
      emptyBytes
    );

    Actions.ActionArgs[] memory actions = new Actions.ActionArgs[](1);
    actions[0] = action;

    SoloMargin(dydxMarket).operate(accounts, actions);

  }


  /// @notice  Converts WETH into ETH through the Canonical WETH contract
  ///
  /// @param   value - The amount to convert back into ETH
  function unwrapETH(uint value) internal {

    address WETH = _storage.getContractAddress(WETH_TOKEN_CONTRACT);

    require(WETH9(WETH).balanceOf(address(this)) >= value, "#DydxImpl unwrapETH(): Not enough WETH balance, considered SP");
    WETH9(WETH).withdraw(value);

  }


  /// @notice  Converts ETH into WETH through the Canonical WETH contract
  ///
  /// @param   value - The amount to convert into WETH
  function wrapETH(uint value) internal {

      address WETH = _storage.getContractAddress(WETH_TOKEN_CONTRACT);

      require(address(this).balance >= value, "#DydxImpl wrapETH(): Not enough ETH balance");
      WETH9(WETH).deposit.value(value)();
      assert(WETH9(WETH).balanceOf(address(this)) >= value);
  }


  /// @notice  Used to add coins support to this Opportunities configuration
  ///
  /// @dev     Internal version so we can call from the constructor and Admin Contract
  ///
  ///          IDs: 0 == ETH, 1 == DAI, 2 == USDC
  ///
  /// @param   principalTokens - The coin contract addresses
  /// @param   primaryIds - dydx term, the id is tied to a coin
  /// @param   secondaryIds - dydx term, the id is tied to a coin
  function _addPrincipalTokens(
    address[] memory principalTokens,
    uint[] memory primaryIds,
    uint[] memory secondaryIds
  )
    internal
  {

    for (uint i = 0; i < principalTokens.length; i++) {

      uint[2] memory market = [primaryIds[i], secondaryIds[i]];

      markets[principalTokens[i]] = market;

    }

  }


  /** ----------------- FALLBACK FUNCTIONS (to be removed before prod. release) ----------------- **/


  function fallbackClaim(uint value, address principalToken, bool isERC20) external onlyGovernance {

    if (isERC20) {

      require(
        IERC20(principalToken).transfer(_storage.getGovernanceWallet(), value),
        "DydxImpl fallbackClaim(): Transfer of ERC20 Token failed"
      );

    } else {

      if (address(this).balance < value) {
          uint supplement = value - address(this).balance;
          WETH9(_storage.getContractAddress(WETH_TOKEN_CONTRACT)).withdraw(supplement);
      }

      _storage.getGovernanceWallet().transfer(value);

    }

  }


  function fallbackWithdrawDydx(uint amountToWithdraw, address principalToken) external onlyGovernance {

    uint primaryMarketId = markets[principalToken][0];
    uint secondaryMarketId = markets[principalToken][1];

    Account.Info memory account = Account.Info(
      address(this),
      0
    );

    Account.Info[] memory accounts = new Account.Info[](1);
    accounts[0] = account;

    Types.AssetAmount memory assetAmount = Types.AssetAmount(
      false,
      Types.AssetDenomination.Wei,
      Types.AssetReference.Delta,
      amountToWithdraw
    );

    bytes memory emptyBytes;

    Actions.ActionArgs memory action = Actions.ActionArgs(
      Actions.ActionType.Withdraw,
      0,
      assetAmount,
      primaryMarketId,
      secondaryMarketId,
      address(this),
      0,
      emptyBytes
    );

    Actions.ActionArgs[] memory actions = new Actions.ActionArgs[](1);
    actions[0] = action;

    SoloMargin(dydxMarket).operate(accounts, actions);

  }

}
