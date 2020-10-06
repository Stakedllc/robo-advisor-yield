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


// external dependencies
import "./openzeppelin/ERC20/ERC20.sol";
import "./openzeppelin/math/SafeMath.sol";

// internal dependencies
import "../interfaces/Opportunity.sol";
import "../interfaces/IRAYToken.sol";
import "../interfaces/Upgradeable.sol";
import "../interfaces/Approves.sol";

import "./Storage.sol";
import "./PositionManager.sol";
import "./NAVCalculator.sol";
import "./wrappers/StorageWrapper.sol";


/// @notice   OpportunityManager handles the interactions with the different
///           Opportunitiies. It's equivalent to what PortfolioManager is to
///           portfolios.
///
/// Author:   Devan Purhar
/// Version:  1.0.0

contract OpportunityManager is Upgradeable, Approves {
  using SafeMath
  for uint256;


  /*************** STORAGE VARIABLE DECLARATIONS **************/


  // contracts used
  bytes32 internal constant ADMIN_CONTRACT = keccak256("AdminContract");
  bytes32 internal constant POSITION_MANAGER_CONTRACT = keccak256("PositionManagerContract");
  bytes32 internal constant OPPORTUNITY_TOKEN_CONTRACT = keccak256("OpportunityTokenContract");
  bytes32 internal constant PORTFOLIO_MANAGER_CONTRACT = keccak256("PortfolioManagerContract");
  bytes32 internal constant STORAGE_WRAPPER_CONTRACT = keccak256("StorageWrapperContract");
  bytes32 internal constant NAV_CALCULATOR_CONTRACT = keccak256("NAVCalculatorContract");

  Storage public _storage;
  bool public deprecated;


  /*************** EVENT DECLARATIONS **************/


  /// @notice  Logs adding supply to an Opportunity
  event LogSupplyToOpportunity(
      bytes32 opportunityId,
      uint value,
      address principalToken
  );


  /// @notice  Logs withdrawing supply from an Opportunity
  event LogWithdrawFromOpportunity(
      bytes32 opportunityId,
      uint value,
      address principalToken
  );


  /*************** MODIFIER DECLARATIONS **************/


  /// @notice  Checks if the token id exists within the Opportunity token contract
  modifier existingOpportunityToken(bytes32 tokenId)
  {
      require(
           IRAYToken(_storage.getContractAddress(OPPORTUNITY_TOKEN_CONTRACT)).tokenExists(tokenId),
          "#OpportunityManager existingOpportunityToken Modifier: This is not a valid Opportunity Token"
      );

      _;
  }


  // validates when we input opportunity addresses (in Oracle) we don't reference invalid
  // or old address
  //
  // todo: Stop passing them in
  modifier isValidOpportunity(bytes32 opportunityId, address opportunity)
  {

    require(
      _storage.getVerifier(opportunityId) == opportunity,
      "#OpportunityManager isValidOpportunity Modifier: This is not a valid Opportunity Address"
    );

    _;

  }


  /// @notice  Checks the caller is our Governance Wallet
  ///
  /// @dev     To be removed once fallbacks are
  modifier onlyGovernance()
  {
      require(
          msg.sender == _storage.getGovernanceWallet(),
          "#OpportunityManager onlyGovernance Modifier: Only Governance can call this"
      );

      _;
  }


  /// @notice  Checks the caller is our Portfolio Manager contract
  modifier onlyPortfolioManager()
  {
      require(
           _storage.getContractAddress(PORTFOLIO_MANAGER_CONTRACT) == msg.sender,
          "#OpportunityManager onlyPortfolioManager Modifier: Only PortfolioManager can call this"
      );

      _;
  }


  /// @notice  Checks the caller is our Admin contract
  modifier onlyAdmin()
  {

    require(
      msg.sender == _storage.getContractAddress(ADMIN_CONTRACT),
      "#OpportunityManager onlyAdmin Modifier: Only the Admin contract can call this"
    );

    _;

  }


  /// @notice  Checks if the Opportunity has been paused.
  ///
  /// @dev     Withdrawals are allowed on pauses, lending or accepting value isn't
  modifier notPaused(bytes32 opportunityId)
  {
      require(
          _storage.getPausedMode(opportunityId) == false,
          "#OpportunityManager notPaused Modifier: In withdraw mode - this function has been paused"
      );

      _;
  }


  /// @notice  Checks if the contract has been set to deprecated
  modifier notDeprecated()
  {
      require(
           deprecated == false,
          "#OpportunityManager notDeprecated Modifier: In deprecated mode - this contract has been deprecated"
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


  /// @notice  Fallback function to receive Ether
  ///
  /// @dev     Required to receive Ether from Opportunity Contracts upon withdraws
  function() external payable {

  }


  /** --------------- PortfolioManager ENTRYPOINTS ----------------- **/


  /// @notice  Entrypoint for PortfolioManager to buy an ETH or ERC20 Opportunity
  ///          Token. Buy == Lend/Supply assets
  ///
  /// @param   opportunityId - The id of the opportunity we're trying to lend too
  /// @param   beneficiary - The owner of the position (currently PortfolioManager)
  /// @param   opportunity - The contract address of the opportunity
  /// @param   principalToken - The coin type
  /// @param   value - The amount we're lending/buying
  /// @param   isERC20 - Tells us if the coin is an ERC20 or not
  ///
  /// @return  The tokenId of the Opportunity Token purchased
  function buyPosition(
    bytes32 opportunityId,
    address beneficiary,
    address opportunity,
    address principalToken,
    uint value,
    bool isERC20
  )
    external
    payable
    onlyPortfolioManager
    notPaused(opportunityId) // check for the Opportunity
    notDeprecated
    isValidOpportunity(opportunityId, opportunity) // check if opp. is deprecated rolled into this, for when opp address externally entered
    returns
    (bytes32)
  {

    // I removed require() that verified value input down to the bottom of this function. It saves us repeating the if (isERC20)
    // statement and though it lets it create the token now, if it fails, it'll revert it anyway.

    // we don't check if the value == 0 above, the call will fail in create Token below if
    // the value sent in is less than 1 share (which is always greater than 0). It'll actually
    // fail if it's below the min. amount of that token which if set properly, will be above
    // zero. I am looking to change the system back from min. amounts to just the technical
    // restriction in a future upgrade

    uint pricePerShare = NAVCalculator(_storage.getContractAddress(NAV_CALCULATOR_CONTRACT)).getOpportunityPricePerShare(opportunityId);

    // Create the Opportunity Token - owner is PortfolioManager in this version
    bytes32 tokenId = PositionManager(_storage.getContractAddress(POSITION_MANAGER_CONTRACT)).createToken(
        opportunityId,
        _storage.getContractAddress(OPPORTUNITY_TOKEN_CONTRACT),
        beneficiary,
        value,
        pricePerShare
    );

    // update amount supplied to the opportunity
    uint newPrincipalValue = _storage.getPrincipal(opportunityId) + value;
    StorageWrapper(_storage.getContractAddress(STORAGE_WRAPPER_CONTRACT)).setPrincipal(opportunityId, newPrincipalValue);

    // don't do payableValue like in increaseTokenCapital to avoid stack to deep error
    if (isERC20) { // put ERC20 first since it should have more demand (at least before ETH staking?)

      require(
        ERC20(principalToken).transferFrom(beneficiary, address(this), value),
        "#OpportunityManager buyPosition: TransferFrom of ERC20 Token failed"
      );
      // don't need to approve the OSC, we auto set max allowance when adding an OSC
      // though that may change when adding external third-party built Opportunities
      // ERC20(principalToken).approve(opportunity, value);
      Opportunity(opportunity).supply(principalToken, value, isERC20);

    } else {

      require(value == msg.value, "#OpportunityManager buyPosition: Value input must match the ETH sent");
      Opportunity(opportunity).supply.value(value)(principalToken, value, isERC20);

    }

    emit LogSupplyToOpportunity(opportunityId, value, principalToken);

    return tokenId;

  }


  /// @notice  Entrypoint for PortfolioManager to increase the ETH or ERC20 value of
  ///          an existing Opportunity token.
  ///
  /// @param   opportunityId - The id of the opportunity token we're increasing value in
  /// @param   tokenId - The unique id of the Opportunity token we're ...
  /// @param   opportunity - The address of the opportunity contract the Opportunity
  ///                        token represents a position in
  /// @param   principalToken - The coin associated with this Opportunity
  /// @param   value - The value in-kind smallest units to increase the tokens value by
  /// @param   isERC20 - Is the principalToken an ERC20 or not / true or false
  function increasePosition(
    bytes32 opportunityId,
    bytes32 tokenId,
    address opportunity,
    address principalToken,
    uint value,
    bool isERC20
  )
    external
    payable
    onlyPortfolioManager
    notPaused(opportunityId) // check for the Opportunity
    notDeprecated
    isValidOpportunity(opportunityId, opportunity)
    existingOpportunityToken(tokenId)
  {

      uint pricePerShare = NAVCalculator(_storage.getContractAddress(NAV_CALCULATOR_CONTRACT)).getOpportunityPricePerShare(opportunityId);

      PositionManager(_storage.getContractAddress(POSITION_MANAGER_CONTRACT)).increaseTokenCapital(
          opportunityId,
          tokenId,
          pricePerShare,
          value
      );

      // update amount supplied to the opportunity
      uint newPrincipalValue = _storage.getPrincipal(opportunityId) + value;
      StorageWrapper(_storage.getContractAddress(STORAGE_WRAPPER_CONTRACT)).setPrincipal(opportunityId, newPrincipalValue);

      uint payableValue;

      // TODO: move this to a function which both buyPosition and this function use
      //       to lend to an Opportunity
      if (isERC20) {

        require(
          ERC20(principalToken).transferFrom(msg.sender, address(this), value),
          "#OpportunityManager increasePosition: TransferFrom of ERC20 Token failed"
        );

        // don't need to approve the Opportunity, we auto set max allowance when
        // adding them, though this may change when adding third-party Opps.
        // ERC20(principalToken).approve(opportunity, value);
        payableValue = 0; // default value, no need to set this here

      } else {

        require(value == msg.value, "#OpportunityManager buyPosition: Value input must match the ETH sent");
        payableValue = value;

      }

      Opportunity(opportunity).supply.value(payableValue)(principalToken, value, isERC20);

      emit LogSupplyToOpportunity(opportunityId, value, principalToken);

  }


  /// @notice  Entrypoint for PortfolioManager to withdraw value from an Opportunity
  ///          Token it owns
  ///
  /// @param   opportunityId - The id associated with the opportunity to withdraw from
  /// @param   tokenId - The unique id of the Opportunity Token to withdraw from
  /// @param   opportunity - The contract address of the Opportunity we're withdrawing from
  /// @param   principalToken - The coin associated with this Opportunity contract
  /// @param   valueToWithdraw - The value in-kind smallest units to withdraw
  /// @param   isERC20 - Is the principalToken an ERC20 or not / true or false
  function withdrawPosition(
    bytes32 opportunityId,
    bytes32 tokenId,
    address opportunity,
    address principalToken,
    uint valueToWithdraw,
    bool isERC20
  )
    external
    onlyPortfolioManager
    notDeprecated
    isValidOpportunity(opportunityId, opportunity)
    existingOpportunityToken(tokenId)
  {

      uint totalValue;
      uint pricePerShare;

      (totalValue, pricePerShare) = NAVCalculator(_storage.getContractAddress(NAV_CALCULATOR_CONTRACT)).getTokenValue(opportunityId, tokenId);

      // verify sender == owner of token, and token value >= value trying to withdraw
      // and value trying to withdraw > min. amount, it returns the owner of the Opportunity token
      // but we don't use it, since in this version it'll always be Portfolio Manager
      PositionManager(_storage.getContractAddress(POSITION_MANAGER_CONTRACT)).verifyWithdrawer(
          opportunityId,
          tokenId,
          _storage.getContractAddress(OPPORTUNITY_TOKEN_CONTRACT),
          msg.sender,
          pricePerShare,
          valueToWithdraw,
          totalValue
      );

      uint withdrawFromPlatform = prepForWithdrawal(opportunityId, opportunity, principalToken, valueToWithdraw);

      // TODO: check if can call this after the token updates state? better re-entrancy
      //       pattern, though we do trust Opportunities added as of now
      Opportunity(opportunity).withdraw(principalToken, address(this), withdrawFromPlatform, isERC20);

      withdrawPosition2(
        opportunityId,
        tokenId,
        valueToWithdraw,
        pricePerShare,
        opportunity,
        principalToken
      );

      emit LogWithdrawFromOpportunity(opportunityId, valueToWithdraw, principalToken);

      // msg.sender is always the PortfolioManager in this version
      if (isERC20) {

        require(
          ERC20(principalToken).transfer(msg.sender, valueToWithdraw),
          "#OpportunityManager withdrawPosition(): Transfer of ERC20 Token failed"
        );

      } else {

        msg.sender.transfer(valueToWithdraw);

      }

  }


  /// @notice  Updates the Opportunity's state re: the withdrawal
  ///
  /// @param   opportunityId - the opportunity id of the one we're withdrawing from
  /// @param   opportunity - the address of the Opportunity
  /// @param   principalToken - the coin associated with the Opportunity
  /// @param   valueToWithdraw - the value to withdraw denominated in-kind smallest units
  ///
  /// @return  the amount to withdraw from the Opportunity
  function prepForWithdrawal(
    bytes32 opportunityId,
    address opportunity,
    address principalToken,
    uint valueToWithdraw
  )
    internal
    returns (uint)
  {

    uint balance = Opportunity(opportunity).getBalance(principalToken);
    uint yield = NAVCalculator(_storage.getContractAddress(NAV_CALCULATOR_CONTRACT)).getOpportunityUnrealizedYield(opportunityId, valueToWithdraw);
    uint capitalWithdrawn = valueToWithdraw - yield; // can't underflow, yield must be <= to the valueToWithdraw

    // shouldn't ever underflow but added check for now anyway (audit suggestion)
    uint newPrincipalAmount = SafeMath.sub(_storage.getPrincipal(opportunityId), capitalWithdrawn); // _storage.getPrincipal(opportunityId) - capitalWithdrawn;
    StorageWrapper(_storage.getContractAddress(STORAGE_WRAPPER_CONTRACT)).setPrincipal(opportunityId, newPrincipalAmount);

    if (yield > 0) {

      NAVCalculator(_storage.getContractAddress(NAV_CALCULATOR_CONTRACT)).updateYield(opportunityId, yield);

    }

    return getWithdrawAmount(balance, valueToWithdraw);

  }


  /// @notice  Calculates how much we'll be withdrawing from the platform to satisfy
  //           the withdrawal request.
  ///
  /// @dev     We may need to withdraw less then the full withdrawal request from
  ///          the Opportunity since when truncuating shares it may cause the PPS
  ///          to slightly gain value they don't have access to.
  ///
  /// @param   oppBalance - Our total balance in the opportunity
  /// @param   totalWithdrawAmount - The total withdrawal request
  ///
  /// @return  Amount to withdraw from the Opportunity
  function getWithdrawAmount(
    uint oppBalance,
    uint totalWithdrawAmount
  )
    internal
    pure
    returns (uint)
  {

    uint withdraw;

    if (oppBalance > totalWithdrawAmount) {

      withdraw = totalWithdrawAmount;

    } else { // will need to use some insurance dust to top off

      withdraw = oppBalance;

    }

    return withdraw;

  }


  /** ----------------- ONLY ADMIN MUTATORS ----------------- **/


  /// @notice  ERC20 approve function, exists to approve Opportunity contracts
  ///          to take the OpportunityManager's value when they need.
  ///
  /// @dev     We currently call this when setting up support for a token in
  ///          the system
  ///
  /// @param   token - address of the coin to give approval for
  /// @param   beneficiary - the receiver of the approval
  /// @param   amount - amount in smallest units of the token
  function approve(
    address token,
    address beneficiary,
    uint amount
  )
    external
    onlyAdmin
    notDeprecated
  {

    require(
      ERC20(token).approve(beneficiary, amount),
      "#OpportunityManager approve(): Approval of ERC20 Token failed"
    );

  }


  /// @notice  Sets the deprecated flag of the contract
  ///
  /// @dev     Used when upgrading a contract
  ///
  /// @param   value - true to deprecate, false to un-deprecate
  function setDeprecated(bool value) external onlyAdmin {

      deprecated = value;

  }


  /********************* INTERNAL FUNCTIONS **********************/


  /// @notice  Part 2 of 2 for withdrawing value from an Opportunity Token.
  ///
  /// @dev     Created two functions to avoid stack too deep compilation error
  ///
  /// @param   opportunityId - The id that corresponds with this Opportunity
  /// @param   tokenId - The unique id of the Opportunity Token we're withdrawing from
  /// @param   valueToWithdraw - The value in-kind smallest units to withdraw
  /// @param   pricePerShare - The current price per share we used earlier in this sequence
  /// @param   opportunity - The contracts address for this Opportunity
  /// @param   principalToken - The coin associated with this Opportunity
  function withdrawPosition2(
    bytes32 opportunityId,
    bytes32 tokenId,
    uint valueToWithdraw,
    uint pricePerShare,
    address opportunity,
    address principalToken
  )
    internal
  {

    uint totalYield = NAVCalculator(_storage.getContractAddress(NAV_CALCULATOR_CONTRACT)).getOpportunityUnrealizedYield(opportunityId, Opportunity(opportunity).getBalance(principalToken));

    PositionManager(_storage.getContractAddress(POSITION_MANAGER_CONTRACT)).updateTokenUponWithdrawal(
        opportunityId,
        tokenId,
        valueToWithdraw,
        pricePerShare,
        _storage.getTokenShares(opportunityId, tokenId),
        totalYield
    );

    reduceCapital(opportunityId, tokenId, valueToWithdraw);

  }


  /// @notice  Reduce the capital the token is credited with upon a withdrawal
  ///
  /// @param   opportunityId - The id associated with this opportunity
  /// @param   tokenId - The unique id of this Opportunity Token
  /// @param   valueToWithdraw - The value being withdrawn in this sequence
  ///
  /// TODO:   Move to PositionManager, where it semantically belongs
  function reduceCapital(
    bytes32 opportunityId,
    bytes32 tokenId,
    uint valueToWithdraw
  )
    internal
  {

      uint capital = _storage.getTokenCapital(opportunityId, tokenId);

      if (valueToWithdraw > capital) {

          // this may already be zero, it should be equal to a 'delete' (refunds gas)
          StorageWrapper(_storage.getContractAddress(STORAGE_WRAPPER_CONTRACT)).setTokenCapital(opportunityId, tokenId, 0);

      } else if (valueToWithdraw <= capital) { // no yield recognized yet

          uint newCapital = capital - valueToWithdraw; // can't underflow due to if() ^
          StorageWrapper(_storage.getContractAddress(STORAGE_WRAPPER_CONTRACT)).setTokenCapital(opportunityId, tokenId, newCapital);

      }

  }


  /** ----------------- FALLBACK FUNCTIONS (to be removed Sept. 26th ----------------- **/


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
        "#OpportunityManager fallbackClaim(): Transfer of ERC20 Token failed"
      );

    } else {

      _storage.getGovernanceWallet().transfer(value);

    }

  }


}
