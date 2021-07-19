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
import "../../../external/bzx/BzxEthInterface.sol";
import "../../../external/bzx/BzxErc20Interface.sol";
import "../../../external/bzx/BzxInterface.sol";
import "../openzeppelin/ERC20/ERC20.sol";

// internal dependency
import "../../interfaces/Opportunity.sol";
import "../../interfaces/MarketByContract.sol";

import "../Storage.sol";


/// Communicating Proxy to the bZx Protocol
///
/// Author:  Devan Purhar
/// Version: 1.0.0

contract BzxOpportunity is Opportunity, MarketByContract {


  /*************** STORAGE VARIABLE DECLARATIONS **************/


  // contracts used
  bytes32 internal constant ADMIN_CONTRACT = keccak256("AdminContract");
  bytes32 internal constant OPPORTUNITY_MANAGER_CONTRACT = keccak256("OpportunityManagerContract");
  bytes32 internal constant WETH_TOKEN_CONTRACT = keccak256("WETHTokenContract"); // only need for fallback

  uint internal constant ON_CHAIN_PRECISION = 1e18;

  Storage public _storage;
  mapping(address => address) public markets;


  /*************** EVENT DECLARATIONS **************/

  /*************** MODIFIER DECLARATIONS **************/


  /// @notice  Checks the caller is our Governance Wallet
  ///
  /// @dev     To be removed once fallbacks are
  modifier onlyGovernance()
  {
      require(
          msg.sender == _storage.getGovernanceWallet(),
          "#BzxOpportunity onlyGovernance Modifier: Only Governance can call this"
      );

      _;
  }


  /// @notice  Checks the caller is our Admin contract
  modifier onlyAdmin()
  {
      require(
          msg.sender == _storage.getContractAddress(ADMIN_CONTRACT),
          "#BzxOpportunity onlyAdmin Modifier: Only Admin can call this"
      );

      _;
  }


  /// @notice  Checks the caller is our OpportunityManager contract
  modifier onlyOpportunityManager()
  {
      require(
          msg.sender == _storage.getContractAddress(OPPORTUNITY_MANAGER_CONTRACT),
          "#BzxOpportunity onlyOpportunityManager Modifier: Only OpportunityManager can call this"
      );

      _;
  }


  /////////////////////// FUNCTION DECLARATIONS BEGIN ///////////////////////

  /******************* PUBLIC FUNCTIONS *******************/


  /// @notice  Sets Storage instance and inits the coins supported by the Opp.
  ///
  /// @dev     The principalTokens and bzxContracts need to correlate by index
  ///
  ///          Ex. principalTokens[0] == DAI Address, bzxContracts[0] == DAI bZx
  ///
  /// @param   __storage - The Storage contracts address
  /// @param   principalTokens - The coin addresses to add support for
  /// @param   bzxContracts - The contract addresses that correlate with the contracts
  constructor(
    address __storage,
    address[] memory principalTokens,
    address[] memory bzxContracts
  )
    public
  {

    _storage = Storage(__storage);

    _addPrincipalTokens(principalTokens, bzxContracts);

  }


  /// @notice  Fallback function to receive Ether
  ///
  /// @dev     Required to receive Ether from Bzx upon withdraws
  function() external payable {

  }


  /** --------------- OpportunityManager ENTRYPOINTS ----------------- **/


  /// @notice  The entrypoint for OpportunityManager to supply assets
  ///
  /// @param    principalToken - The coin address to lend
  /// @param    value - The amount to supply in the smallest units in-kind
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

    uint mintAmount;
    address bzxMarket = markets[principalToken];

    if (isERC20) {

      require(
        ERC20(principalToken).transferFrom(msg.sender, address(this), value),
        "#BzxOpportunity supply(): TransferFrom of ERC20 Token failed"
      );

      /// @notice  The method to supply ERC20's for this Opportunity
      ///
      /// @dev     We trust the external contract we call here (no re-entrancy)

      // give allowance to Bzx to use our ERC20 balance
      require(
        ERC20(principalToken).approve(bzxMarket, value),
        "BzxImpl supply(): Approval of ERC20 Token failed"
      );

      mintAmount = BzxErc20Interface(bzxMarket).mint(address(this), value);

    } else {

      /// @notice  The method to supply ETH for this Opportunity
      ///
      /// @dev     We trust the external contract we call here (no re-entrancy)

      // ETH lending on Bzx returns the amount of the underlying we minted
      mintAmount = BzxEthInterface(bzxMarket).mintWithEther.value(msg.value)(address(this));

    }

    require(
      mintAmount > 0,
      "#BzxOpportunity supply(): Must have minted at least one bZx lending token"
    );

  }


  /// @notice  The entrypoint for OpportunityManager to withdraw assets
  ///
  /// @param    principalToken - The coin address to withdraw
  /// @param    beneficiary - The address to send funds too - always OpportunityManager for now
  /// @param    valueToWithdraw - The amount to withdraw in-kind smallest units
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

    uint valueRepaid;
    address bzxMarket = markets[principalToken];

    require(
      getMarketLiquidity(bzxMarket) > valueToWithdraw,
      "#BzxOpportunity withdraw(): Bzx market has insufficient liquidity"
    );

    uint amountOfTokens = convertToBzxTokens(bzxMarket, valueToWithdraw);

    if (isERC20) {

      /// @notice  The method to withdraw ERC20's for this Opportunity
      ///
      /// @dev     We trust the external contract we call here (no re-entrancy)

      valueRepaid = BzxErc20Interface(bzxMarket).burn(address(this), amountOfTokens);

      require(
        valueRepaid >= valueToWithdraw,
        "#BzxOpportunity withdraw(): [ERC20] Repaid must be greater or equal to value to withdraw"
      );

      require(
        ERC20(principalToken).transfer(beneficiary, valueRepaid),
        "BzxImpl withdraw(): Transfer of ERC20 Token failed"
      );

    } else {

      /// @notice  The method to withdraw ETH for this Opportunity
      ///
      /// @dev     We trust the external contract we call here (no re-entrancy)

      valueRepaid = BzxEthInterface(bzxMarket).burnToEther(address(this), amountOfTokens);

      require(
        valueRepaid >= valueToWithdraw,
        "#BzxOpportunity withdraw(): [ETH] Repaid must be greater or equal to value to withdraw"
      );

      // transferring to ourselves, don't worry about unpayable contract
      beneficiary.transfer(valueRepaid);

    }

  }


  /** ----------------- ONLY ADMIN MUTATORS ----------------- **/


  /// @notice  Add support for a coin
  ///
  /// @dev     This is configured in-contract since it's not common across Opportunities
  ///
  /// @param   principalTokens - The coin contract addresses
  /// @param   bzxContracts - The bZx contracts that map to each coin
  function addPrincipalTokens(
    address[] memory principalTokens,
    address[] memory bzxContracts
  )
    public // not using external b/c use memory to pass in array
    onlyAdmin
  {

    // thought about putting this type info in coinstate but it's not the same type across protocols so needs to be local
    _addPrincipalTokens(principalTokens, bzxContracts);

  }


  /** ----------------- VIEW ACCESSORS ----------------- **/


  /// @notice  Get the current balance we have in the Opp. (principal + interest generated)
  ///
  /// @param   principalToken - The coins address
  ///
  /// @return  The total balance in the smallest units of the coin
  function getBalance(address principalToken) external view returns(uint) {

      address bzxToken = markets[principalToken];

      uint currBzxBalance = BzxInterface(bzxToken).assetBalanceOf(address(this));

      return currBzxBalance;

  }


  /// @notice  Gets the market liquidity of the specified coin type
  ///
  /// @param   bzxMarket - The address of the bZx contract
  ///
  /// @return  the markets liqudity in the smallest unit of the coin
  function getMarketLiquidity(address bzxMarket) public view returns(uint) {

    return BzxInterface(bzxMarket).marketLiquidity();

  }


  /*************** INTERNAL FUNCTIONS **************/


  /// @notice  Converts an amount of value to bZx tokens
  ///
  /// @param   bzxMarket - the corresponding bZx contract address
  /// @param   valueToWithdraw - the value being withdrawn
  function convertToBzxTokens(
    address bzxMarket,
    uint valueToWithdraw
  )
    internal
    view
    returns (uint)
  {

    uint tokenPrice = BzxInterface(bzxMarket).tokenPrice();
    uint amountOfTokens = valueToWithdraw * ON_CHAIN_PRECISION / tokenPrice;

    if ((amountOfTokens * tokenPrice / ON_CHAIN_PRECISION) < valueToWithdraw) {

      amountOfTokens++;

    }

    return amountOfTokens;

  }


  /// @notice  Used to add coins support to this Opportunities configuration
  ///
  /// @dev     Internal version so we can call from the constructor and Admin Contract
  ///
  /// @param   principalTokens - The coin contract addresses
  /// @param   bzxContracts - The bZx platform contracts that map to each coin
  function _addPrincipalTokens(
    address[] memory principalTokens,
    address[] memory bzxContracts
  )
    internal
  {

    for (uint i = 0; i < principalTokens.length; i++) {

      markets[principalTokens[i]] = bzxContracts[i];

    }

  }


  /** ----------------- FALLBACK FUNCTIONS (to be removed) ----------------- **/


  function fallbackClaim(
    uint value,
    address principalToken,
    bool isERC20
  )
    external
    onlyGovernance
  {

    if (isERC20) {

      require(
        ERC20(principalToken).transfer(_storage.getGovernanceWallet(), value),
        "BzxImpl fallbackClaim(): Transfer of ERC20 Token failed"
      );

    } else {

      _storage.getGovernanceWallet().transfer(value);

    }

  }


  function fallbackWithdrawBzx(
    uint amountOfTokens,
    address principalToken
  )
    external
    onlyGovernance
  {

    if (principalToken == _storage.getContractAddress(WETH_TOKEN_CONTRACT)) {

        BzxEthInterface(markets[principalToken]).burnToEther(address(this), amountOfTokens);

    } else {

       BzxErc20Interface(markets[principalToken]).burn(address(this), amountOfTokens);

    }

  }

}
