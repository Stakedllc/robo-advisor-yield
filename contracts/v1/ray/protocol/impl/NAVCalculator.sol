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

// internal dependencies
import "../interfaces/IRAYToken.sol";
import "../interfaces/Opportunity.sol";
import "../interfaces/Upgradeable.sol";

import "./Storage.sol";
import "./wrappers/StorageWrapper.sol";


/// @notice  NAVCalculator generally holds functions to calculate the NAV and
///          calculate the value or portfolio [RAY] and opportunity tokens.
///          However, it does contain functions not semantically correct
///          but I've put them here for now to avoid PortfolioManager being
///          to large (reduce bytecode) and also avoid creating more contracts.
///
/// Author:   Devan Purhar
/// Version:  1.0.0

contract NAVCalculator is Upgradeable {
  using SafeMath
  for uint256;


  /*************** STORAGE VARIABLE DECLARATIONS **************/


  // contracts used
  bytes32 internal constant ADMIN_CONTRACT = keccak256("AdminContract");
  bytes32 internal constant RAY_TOKEN_CONTRACT = keccak256("RAYTokenContract");
  bytes32 internal constant PAYER_CONTRACT = keccak256("PayerContract");
  bytes32 internal constant OPPORTUNITY_MANAGER_CONTRACT = keccak256("OpportunityManagerContract");
  bytes32 internal constant OPPORTUNITY_TOKEN_CONTRACT = keccak256("OpportunityTokenContract");
  bytes32 internal constant STORAGE_WRAPPER_CONTRACT = keccak256("StorageWrapperContract");

  uint internal constant ON_CHAIN_PRECISION = 1e18;
  uint internal constant BASE_PRICE_IN_WEI = 1 wei;

  Storage public _storage;
  bool public deprecated;


  /*************** MODIFIER DECLARATIONS **************/


  /// @notice  Checks the caller is our Admin contract
  modifier onlyAdmin()
  {

    require(
      msg.sender == _storage.getContractAddress(ADMIN_CONTRACT),
      "#NavCalculator onlyAdmin Modifier: Only the Admin contract can call this"
    );

    _;

  }


  /// @notice  Requires the sender be OpportunityManager or one of our PortfolioManager's
  modifier onlyPortfolioOrOpportunityManager(bytes32 contractId)
  {
      require(
            msg.sender == _storage.getVerifier(contractId) ||
            msg.sender == _storage.getContractAddress(OPPORTUNITY_MANAGER_CONTRACT),
          "#NAVCalculator onlyPortfolioOrOpportunityManager Modifier: This is not a valid contract calling"
      );

      _;
  }



  /// @notice  Checks if the contract has been set to deprecated
  modifier notDeprecated()
  {
      require(
           deprecated == false,
          "#NavCalculator notDeprecated Modifier: In deprecated mode - this contract has been deprecated"
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


  /// @notice  Update the yield after withdrawing it
  ///
  /// @dev     Yield is always greater than zero when this is called
  ///
  /// @param   portfolioId - The portfolio id
  /// @param   yield - The yield withdrawn in
  function updateYield(
    bytes32 portfolioId,
    uint yield
  )
    external
    notDeprecated
    onlyPortfolioOrOpportunityManager(portfolioId)
  {

    uint withdrawnYield = _storage.getWithdrawnYield(portfolioId);

    if (withdrawnYield < yield) {

        uint difference = yield - withdrawnYield; // can't underflow due to the if()
        StorageWrapper(_storage.getContractAddress(STORAGE_WRAPPER_CONTRACT)).setWithdrawnYield(portfolioId, 0);
        // realizedYield += difference;
        StorageWrapper(_storage.getContractAddress(STORAGE_WRAPPER_CONTRACT)).setRealizedYield(portfolioId, _storage.getRealizedYield(portfolioId) + difference);

    } else {

        // withdrawnYield -= yield;
        // can't underflow due to the if()
        StorageWrapper(_storage.getContractAddress(STORAGE_WRAPPER_CONTRACT)).setWithdrawnYield(portfolioId, withdrawnYield - yield);

    }

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


  /** ----------------- VIEW ACCESSORS ----------------- **/


  /// @notice  Calculates the current price per share
  ///
  /// @param   portfolioId - The portfolio id
  ///
  /// @return  The price per share scaled by ON_CHAIN_PRECISION
  function getPricePerShare(
    bytes32 portfolioId,
    uint unrealizedYield
  )
    public
    notDeprecated
    view
    returns (uint)
  {

      uint yield = getTotalYieldPerShare(portfolioId, unrealizedYield);
      uint scaledPrice = BASE_PRICE_IN_WEI * ON_CHAIN_PRECISION;
      return yield + scaledPrice;

  }


  /// @notice  Calculates the current yield per share
  ///
  /// @param   portfolioId - The portfolio id
  ///
  /// @return   The yield per share scaled by ON_CHAIN_PRECISION
  function getTotalYieldPerShare(
    bytes32 portfolioId,
    uint unrealizedYield
  )
    public
    view
    notDeprecated
    returns (uint)
  {

      uint shareSupply = _storage.getShareSupply(portfolioId);

      if (shareSupply > 0) {

          uint realizedYield = _storage.getRealizedYield(portfolioId);
          uint withdrawnYield = _storage.getWithdrawnYield(portfolioId);

          uint totalYield = getTotalYield(unrealizedYield, realizedYield, withdrawnYield);
          uint raised = _storage.getRaised(_storage.getPrincipalAddress(portfolioId));

          return (totalYield * raised) / shareSupply;

      } else {

          return 0;

      }

  }


  /// @notice  Calculates the total yield when considering all factors
  ///
  /// @param   unrealizedYield - The unrealized yield of the portfolio
  /// @param   realizedYield - The realized yield of this portfolio
  /// @param   withdrawnYield - The withdrawn yield of this portfolio
  ///
  /// @return  The total yield
  function getTotalYield(
    uint unrealizedYield,
    uint realizedYield,
    uint withdrawnYield
  )
    public
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


  /// @notice  Sums the unrealized yield from all the opportunities in this portfolio
  ///
  /// @param   portfolioId - The portfolio id
  ///
  /// @return  The total unrealized yield
  function getPortfolioUnrealizedYield(bytes32 portfolioId) public notDeprecated view returns (uint) {

    uint unrealizedYield;
    bytes32[] memory opportunities;
    opportunities = _storage.getOpportunities(portfolioId);

    for (uint i = 0; i < opportunities.length; i++) {

        bytes32 opportunityId = opportunities[i];
        uint balance = getOpportunityBalance(portfolioId, opportunityId);

        if (balance != 0) {

          unrealizedYield += getOpportunityYield(portfolioId, opportunityId, balance);

        }

    }

    return unrealizedYield;

  }


  /// @notice  Gets the amount of yield earnt based on an amount being withdrawn
  ///          for an Opportunity.
  ///
  /// @param   portfolioId - The portfolio id
  /// @param   amountToWithdraw - The amount being withdraw
  ///
  /// @return  The total unrealized yield
  function getOpportunityUnrealizedYield(
    bytes32 portfolioId,
    uint amountToWithdraw
  )
    public
    view
    returns (uint)
  {

      uint principalAmount = _storage.getPrincipal(portfolioId);

      if (principalAmount >= amountToWithdraw) {


          return 0; // we aren't withdrawing any yield, we prioritize taking principal out first

      }

      uint yield = amountToWithdraw - principalAmount; // can't underflow due to if() ^

      return yield;
  }


  /// @notice  Calculate how much yield a generic Opportunity has made
  ///
  /// @param   portfolioId - The portfolio id
  /// @param   opportunityId - The opportunity id
  /// @param   amountToWithdraw - The amount we're trying to check if we have yield on if we withdrew
  ///
  /// @return  The amount of yield this opportunity has if we withdraw a certain value
  function getOpportunityYield(
    bytes32 portfolioId,
    bytes32 opportunityId,
    uint amountToWithdraw
  )
    public
    notDeprecated
    view
    returns (uint)
 {

      bytes32 tokenId = _storage.getOpportunityToken(portfolioId, opportunityId);
      uint principalAmount =  _storage.getTokenCapital(opportunityId, tokenId);

      if (principalAmount >= amountToWithdraw) {

          return 0;

      }

      uint yield = amountToWithdraw - principalAmount; // can't underflow due to if() ^
      return yield;
  }


  /// @notice  Get the total value of a generic Opportunity
  ///
  /// @param   portfolioId - The portfolio id
  /// @param   opportunityId - The opportunity id
  ///
  /// @return  The total value of the Opportunity (capital + yield)
  function getOpportunityBalance(
    bytes32 portfolioId,
    bytes32 opportunityId
  )
    public
    notDeprecated
    view
    returns(uint)
  {

      bytes32 tokenId = _storage.getOpportunityToken(portfolioId, opportunityId);

      uint tokenValue;
      uint pricePerShare;

      if (tokenId != bytes32(0)) { // if we've lent to this opporunity

        (tokenValue, pricePerShare) = getTokenValue(opportunityId, tokenId);

      }

      return tokenValue;
  }


  /// @notice  Decides how much value we need to send to our OpportunityManager function
  ///          that accepts ETH and ERC20's. It does this by checking if the
  ///          coin in question is an ERC20 or not.
  ///
  /// @param   principalToken - The coin we're checking for
  /// @param   value - The amount of value in the coin we need to send
  function calculatePayableAmount(
    address principalToken,
    uint value
  )
    external
    notDeprecated
    view
    returns(bool, uint)
  {

      bool isERC20 = _storage.getIsERC20(principalToken);
      uint payableValue;

      if (isERC20) {

        payableValue = 0;

      } else {

        payableValue = value;

      }

      return (isERC20, payableValue);

  }



  /// @notice  Checks that if the msg.sender == our Payer contract and then the
  ///          original caller == the true owner. We can do this since we trust
  ///          Payer (ours). Else, msg.sender must be the true owner of the token.
  ///
  /// @dev     This function exists so we can support paying for user transactions.
  ///
  /// @param   tokenId - The unique id of the position in question
  /// @param   origCaller - The address that signed the transaction that went through Payer
  /// @param   msgSender - The msg.sender to the function in PortfolioManager
  function onlyTokenOwner(
    bytes32 tokenId,
    address origCaller,
    address msgSender
  )
    external
    notDeprecated
    view
    returns (address)
  {

      if (msgSender == _storage.getContractAddress(PAYER_CONTRACT)) {

        require(IRAYToken(_storage.getContractAddress(RAY_TOKEN_CONTRACT)).ownerOf(uint(tokenId)) == origCaller,
                "#RAY onlyTokenOwner modifier: The original caller is not the owner of the token");

        return origCaller;

      } else {

        require(IRAYToken(_storage.getContractAddress(RAY_TOKEN_CONTRACT)).ownerOf(uint(tokenId)) == msgSender,
                "#RAY onlyTokenOwner modifier: The caller is not the owner of the token");

        return msgSender;

      }

  }


  /// @notice  Calculates the current token value
  ///
  /// @dev     (price per share * shares)
  ///
  /// @param    typeId - The portfolio / opportunity id
  /// @param    tokenId - The unique token id
  ///
  /// @return   Value of the token and price per share used to calculate it
  function getTokenValue(
    bytes32 typeId,
    bytes32 tokenId
  )
    public
    view
    returns(uint, uint)
  {

      uint pricePerShare;

      if (IRAYToken(_storage.getContractAddress(RAY_TOKEN_CONTRACT)).tokenExists(tokenId)) {

        pricePerShare = getPortfolioPricePerShare(typeId);

      } else if (IRAYToken(_storage.getContractAddress(OPPORTUNITY_TOKEN_CONTRACT)).tokenExists(tokenId)) {

        pricePerShare = getOpportunityPricePerShare(typeId);

      } else {

        require(1 == 0, "#NAVCalculator getTokenValue(): Invalid tokenId");

      }

      uint raised = _storage.getRaised(_storage.getPrincipalAddress(typeId));
      uint tokenValue = pricePerShare * _storage.getTokenShares(typeId, tokenId) / raised;

      return (tokenValue, pricePerShare);
  }


  /// @notice  Helper to get a portfolios price per share
  ///
  /// @param   portfolioId - The portfolio id
  ///
  /// @return  The price per share of the portfolio
  function getPortfolioPricePerShare(bytes32 portfolioId) public view returns (uint) {

    uint unrealizedYield = getPortfolioUnrealizedYield(portfolioId);

    return getPricePerShare(portfolioId, unrealizedYield);

  }


  /// @notice  Helper to get an opportunities price per share
  ///
  /// @param   opportunityId - The opportunity id
  ///
  /// @return  The price per share of the opportunity
  function getOpportunityPricePerShare(bytes32 opportunityId) public view returns (uint) {

    address opportunity = _storage.getVerifier(opportunityId);
    address principalAddress = _storage.getPrincipalAddress(opportunityId);
    uint unrealizedYield = getOpportunityUnrealizedYield(opportunityId, Opportunity(opportunity).getBalance(principalAddress));

    return getPricePerShare(opportunityId, unrealizedYield);

  }


}
