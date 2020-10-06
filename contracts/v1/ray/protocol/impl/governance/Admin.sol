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


// internal dependencies
import "../../interfaces/IPortfolioManager.sol";
import "../../interfaces/Upgradeable.sol";
import "../../interfaces/Approves.sol";
import "../../interfaces/MarketByContract.sol";
import "../../interfaces/MarketByNumber.sol";
import "../../interfaces/IRAYToken.sol";

import "../FeeModel.sol";
import "../Oracle.sol";
import "../Storage.sol";
import "../secondary/Entrypoint.sol";
import "../wrappers/StorageWrapper.sol";
import "../wrappers/StorageWrapperTwo.sol";


/// @notice  Admin controls all 'governance' or configuring of the RAY system.
///
/// @dev     Everything is controlled by the address set to 'Governance'. Initially
///          this will be a wallet Staked controls.
///
///          Over time, Staked will create a governance token and set governance
///          to the smart contract which enables holders of the tokens power over
///          the Admin contract.
///
/// Author:   Devan Purhar
/// Version:  1.0.0

contract Admin is Upgradeable {


  /*************** STORAGE VARIABLE DECLARATIONS **************/


  // contracts used
  bytes32 internal constant STORAGE_WRAPPER_CONTRACT = keccak256("StorageWrapperContract");
  bytes32 internal constant STORAGE_WRAPPER_TWO_CONTRACT = keccak256("StorageWrapperTwoContract");
  bytes32 internal constant OPPORTUNITY_TOKEN_CONTRACT = keccak256("OpportunityTokenContract");
  bytes32 internal constant FEE_MODEL_CONTRACT = keccak256("FeeModelContract");
  bytes32 internal constant ORACLE_CONTRACT = keccak256("OracleContract");
  bytes32 internal constant ENTRYPOINT_CONTRACT = keccak256("EntrypointContract");

  uint internal constant ON_CHAIN_PRECISION = 1e18;
  uint internal constant THREE_DECIMAL_PRECISION = 100000;
  address internal constant NULL_ADDRESS = address(0);

  Storage public _storage;
  bool public deprecated;

  // verified addresses to assist setting Governance wallet
  mapping(address => bool) public assistants;
  // verified addresses to set the benchmark rate
  mapping(address => bool) public rateModifiers;


  /*************** EVENT DECLARATIONS **************/


  /// @notice  Logs adding an Opportunity
  event LogAddOpportunity(
      bytes32 indexed portfolio,
      bytes32 opportunityId,
      address principalAddress
  );


  /// @notice  Logs setting the benchmark rate
  event LogSetBenchmarkRate(
    address principalAddress,
    uint rate
  );


  /// @notice  Logs setting the RAY fee percentage
  event LogSetRAYFee(
    uint newFee
  );


  /// @notice  Logs pausing a portfolio / RAY
  event LogSetPausedOn(
    bytes32 key
  );


  /// @notice  Logs un-pausing a portfolio / RAY
  event LogSetPausedOff(
    bytes32 key
  );


  /// @notice  Logs upgrading PortfolioManager
  event LogUpgradePortfolioManager(
    address currRay,
    address newRay,
    bytes32[] tokenIds,
    bytes32[] keys,
    uint[] balances
  );


  /// @notice  Logs granting an ERC20 approval
  event LogERC20Approval(
    address target,
    address token,
    address beneficiary,
    uint amount
  );


  /// @notice  Logs setting a contract in the RAY system
  event LogSetContractAddress(
    bytes32[] contractNames,
    address[] contractAddresses
  );


  /// @notice  Logs setting an opportunities supported coins
  event LogSetOpportunityPT(
    bytes32[] opportunityNames,
    address[] principalTokens
  );


  /// @notice  Logs setting up a coin in the RAY system
  event LogSetCoinSetting(
    address[] principalTokens,
    bool[] isERC20s,
    uint[] minAmounts,
    uint[] raised
  );


  /// @notice  Logs setting the Governance wallet/address
  event LogSetGovernanceWallet(
    address newGovernanceWallet
  );


  /// @notice  Logs setting a Storage Wrapper
  event LogSetStorageWrapper(
    address _address,
    bool action
  );


  /// @notice  Logs setting an Assistant
  event LogSetAssistantWallet(
    address _address,
    bool action
  );


  /// @notice  Logs setting a Rate Modifier
  event LogSetRateModifier(
    address _address,
    bool action
  );


  /// @notice  Logs an overwrite (therefore upgrade) of a contract in Verifier
  event LogOverwriteInVerifier(
    bytes32 key,
    address overwrittenAddress,
    address newAddress
  );


  /// @notice  Logs setting the verifier
  event LogSetVerifier(
    bytes32[] portfolioKeys,
    address[] contractAddresses
  );


  /// @notice  Logs upgrading tokens
  event LogUpgradeTokens(
    bytes32[] tokenIds
  );


  /// @notice  Logs adding support for a market for "by-contract" Opportunities
  event LogAddMarketByContract(
    address opportunity,
    address[] principalTokens,
    address[] contracts
  );


  /// @notice  Logs adding support for a market for "by-number" Opportunities
  event LogAddMarketByNumber(
    address opportunity,
    address[] principalTokens,
    uint[] primaryIds,
    uint[] secondaryIds
  );


  /// @notice  Logs setting a contract's deprecated status
  event LogSetDeprecatedStatus(
    address theContract,
    bool status
  );


  /// @notice  Logs claiming fees from a portfolio
  event LogClaimFees(
    bytes32 key,
    uint revenue
  );


  /// @notice  Logs setting an off-chain Oracle
  event LogSetOracle(
    address oracle,
    bool action
  );


  /// @notice  Logs withdrawing in preparation of an upgrade
  event LogWithdrawForUpgrade(
    bytes32 key,
    bytes32 opportunityKey,
    address opportunity,
    uint value
  );


  /// @notice  Logs deprecating the Admin contract
  event LogSetDeprecatedAdmin(
    bool value
  );


  /*************** MODIFIER DECLARATIONS **************/


  /// @notice  Checks the caller is our Governance Wallet
  modifier onlyGovernance()
  {
      require(
          msg.sender == _storage.getGovernanceWallet(),
          "#Admin onlyGovernance Modifier: Only Governance can call this"
      );

      _;
  }


  /// @notice  Checks if the contract has been set to deprecated
  modifier notDeprecated()
  {
      require(
           deprecated == false,
          "#Admin notDeprecated Modifier: In deprecated mode - this contract has been deprecated"
      );

      _;
  }


  /////////////////////// FUNCTION DECLARATIONS BEGIN ///////////////////////

  /******************* PUBLIC FUNCTIONS *******************/


  /// @notice  Sets the Storage contract instance
  ///
  /// @param   __storage - The Storage contracts address
  constructor(
    address __storage
  )
      public
  {

    _storage = Storage(__storage);

  }


  /** ----------------- ONLY GOVERNANCE MUTATORS ----------------- **/


  /// @notice  Set the benchmark rate we use
  ///
  /// @dev     Ex. 2.5% APR is newRate = 2500
  ///
  /// @param   principalAddress - The coin address
  /// @param   newRate - The new rate
  ///
  /// TODO:    Add variance restrictions here - governance
  function setBenchmarkRate(address principalAddress, uint newRate) external notDeprecated {

    // require the msg.sender either be Governance Wallet or a Rate Modifier
    require(
      msg.sender == _storage.getGovernanceWallet() ||
      rateModifiers[msg.sender] == true,
      "#Admin setBenchmarkRate(): Only Governance or Rate Modifiers can access this."
    );

    FeeModel(_storage.getContractAddress(FEE_MODEL_CONTRACT)).updateCumulativeRate(principalAddress);
    uint rate = newRate * ON_CHAIN_PRECISION / THREE_DECIMAL_PRECISION; // ex. rate == 2500 == 2.5%

    StorageWrapperTwo(_storage.getContractAddress(STORAGE_WRAPPER_TWO_CONTRACT)).setBenchmarkRate(principalAddress, rate);

    emit LogSetBenchmarkRate(principalAddress, rate);

  }


  /// @notice  Set the RAY fee we use
  ///
  /// @dev     Ex. 20% is newFee = 5
  ///
  /// @param   newFee - The new fee
  function setRAYFee(uint newFee) external notDeprecated onlyGovernance {

    FeeModel(_storage.getContractAddress(FEE_MODEL_CONTRACT)).setRAYFee(newFee);

    emit LogSetRAYFee(newFee);

  }


  /// @notice  Pause portfolios or opportunities (only PortfolioManager and Opportunities)
  ///
  /// @param    key - The portfolio key of the portfolio you're pausing or the
  ///                 name of the contract (if you wish to pause all portfolios)
  function setPausedOn(bytes32 key) external notDeprecated onlyGovernance {

    StorageWrapper(_storage.getContractAddress(STORAGE_WRAPPER_CONTRACT)).setPausedOn(key);

    emit LogSetPausedOn(key);

  }


  /// @notice  Un-pause portfolios or opportunities (only PortfolioManager and Opportunities)
  ///
  /// @param    key - The portfolio key of the portfolio you're pausing or the
  ///                 name of the contract (if you wish to pause all portfolios)
  function setPausedOff(bytes32 key) external notDeprecated onlyGovernance {

    StorageWrapper(_storage.getContractAddress(STORAGE_WRAPPER_CONTRACT)).setPausedOff(key);

    emit LogSetPausedOff(key);

  }


  /// @notice  Add the valid opportunities of a portfolio
  ///
  /// @param   key - The portfolio key
  /// @param   _opportunities - The opportunity key's
  /// @param   principalAddress - The coin type of this portfolio
  function addOpportunities(
    bytes32 key,
    bytes32[] memory _opportunities,
    address principalAddress
  )
    public // not using external b/c use memory to pass in array
    notDeprecated
    onlyGovernance
  {

    for (uint i = 0; i < _opportunities.length; i++) {

      // We redundantly set the principal address in Storage with this method.
      // The principal address doesn't change per portfolio...
      // TODO: Fix this in-efficient storage usage
      StorageWrapper(_storage.getContractAddress(STORAGE_WRAPPER_CONTRACT)).addOpportunity(
        key,
        _opportunities[i],
        principalAddress
      );

      StorageWrapper(_storage.getContractAddress(STORAGE_WRAPPER_CONTRACT)).setValidOpportunity(key, _opportunities[i]); // quicker access

      emit LogAddOpportunity(
        key,
        _opportunities[i],
        principalAddress
      );

    }

  }


  /// @notice  Upgrade to a new PortfolioManager contract.
  ///
  /// @dev     This will withdraw all the value in outside platforms back into
  ///          our contract then transfers it all as ETH to the next logic contract.
  ///
  ///          It transfers ALL value to the new contract. We could also claim the
  ///          AlphaGenerated and reset it to 0 here. All value is the Opportunity Tokens,
  ///          alpha generated, and insurance dust.
  ///
  ///          Will have to make this a bit more trustless with governance or
  ///          something similar to ensure we can't just send all the value in the
  ///          contract to wherever we wish
  ///
  ///          Off-chain need to still replace new contract's address in the Storage
  ///          verifier mapping
  ///
  /// @param   currRay - Address of the current PortfolioManager (old one)
  /// @param   newRay - Address of the new PortfolioManager
  /// @param   tokenIds - The Opportunity tokens to transfer
  /// @param   keys - The keys of different portfolios we want to transfer
  /// @param   balances - All balance of the corresponding index in keys
  ///          Ex. keys[0] = EthCompound, balances[0] = ETH A.C. and ACPContribution
  ///
  /// NOTE:   What gets input is pretty important to be accurate, could get the balances on-chain
  ///         but costs more gas...
  function deprecatePortfolioManager(
    address currRay,
    address newRay,
    bytes32[] tokenIds,
    bytes32[] keys, // one key of each principal type
    uint[] balances
  )
    public // not using external b/c use memory to pass in array
    notDeprecated
    onlyGovernance
  {

      address opportunityToken = _storage.getContractAddress(OPPORTUNITY_TOKEN_CONTRACT);

      IPortfolioManager(currRay).setApprovalForAll(opportunityToken, address(this), true);

      for (uint i = 0; i < tokenIds.length; i++) {

        IRAYToken(opportunityToken).safeTransferFrom(currRay, newRay, uint(tokenIds[i])); // transfer all tokens to new PortfolioManager

      }

      for (i = 0; i < keys.length; i++) {

        IPortfolioManager(currRay).transferFunds(keys[i], newRay, balances[i]);

      }

      Upgradeable(currRay).setDeprecated(true);

      emit LogUpgradePortfolioManager(currRay, newRay, tokenIds, keys, balances);

  }


  /// @notice  Approve a contract for ERC20
  ///
  /// @dev     Currently use to approve PortfolioManager to OpportunityManager,
  ///          and OpportunityManager to Opportunities
  ///
  /// @param   target - The contract to call approve in
  /// @param   token - The token to set the approval for
  /// @param   beneficiary - The address receiving the approval
  /// @param   amount - The amount to approve them too
  function approve(
    address target,
    address token,
    address beneficiary,
    uint amount
  )
    external
    notDeprecated
    onlyGovernance
  {

    Approves(target).approve(token, beneficiary, amount);

    emit LogERC20Approval(target, token, beneficiary, amount);

  }


  /// @notice  Set contract addresse
  ///
  /// @dev     The indexes in the two arrays need to correspond
  ///
  ///           Ex. contractNames[0] = keccak256('OpportunityManager'),
  ///               contractAddresses[0] = OpportunityManager.address
  ///
  /// @param    contractNames - The keccak256() of the name with 'Contract' appended
  /// @param    contractAddresses - The addresses of the contracts
  function setContractsAddress(
    bytes32[] memory contractNames,
    address[] memory contractAddresses
  )
    public // not using external b/c use memory to pass in array
    notDeprecated
    onlyGovernance
  {

    address storageWrapperTwo = _storage.getContractAddress(STORAGE_WRAPPER_TWO_CONTRACT);

    for (uint i = 0; i < contractNames.length; i++) {

      StorageWrapperTwo(storageWrapperTwo).setContractAddress(contractNames[i], contractAddresses[i]);

    }

    emit LogSetContractAddress(contractNames, contractAddresses);

  }


  /// @notice  Set the Opportunity contracts principal tokens
  ///
  /// @dev     Indexes need to correspond
  ///
  /// @param   implNames - The keccak256() of the Opportunity Impls. name
  /// @param   principalTokens - The address of the coin the Opportunity Impl uses
  function setImplsPrincipalToken(
    bytes32[] memory implNames,
    address[] memory principalTokens
  )
    public // not using external b/c use memory to pass in array
    notDeprecated
    onlyGovernance
  {

    address storageWrapperTwo = _storage.getContractAddress(STORAGE_WRAPPER_TWO_CONTRACT);

    for (uint i = 0; i < implNames.length; i++) {

      StorageWrapperTwo(storageWrapperTwo).setPrincipalAddress(implNames[i], principalTokens[i]);

    }

    emit LogSetOpportunityPT(implNames, principalTokens);

  }


  /// @notice  Configure the settings of a coin to add support in the system for it
  ///
  /// @dev     Indexes need to correspond
  ///
  /// @param   principalTokens - The coin addresses to support
  /// @param   isERC20s - Is it an ERC20 coin or not (only ETH this far isn't)
  /// @param   minAmounts - The min. amount somebody can deposit or withdraw of a coin
  ///
  /// TODO:    Remove min. amount restriction, handle GUI side (which will effect this function)
  function setCoinSettings(
    address[] memory principalTokens,
    bool[] memory isERC20s,
    uint[] memory minAmounts,
    uint[] memory raised
  )
    public // not using external b/c use memory to pass in array
    notDeprecated
    onlyGovernance
  {

    address storageWrapperTwo = _storage.getContractAddress(STORAGE_WRAPPER_TWO_CONTRACT);

    for (uint i = 0; i < principalTokens.length; i++) {

      StorageWrapperTwo(storageWrapperTwo).setIsERC20(principalTokens[i], isERC20s[i]);
      StorageWrapperTwo(storageWrapperTwo).setMinAmount(principalTokens[i], minAmounts[i]);
      StorageWrapperTwo(storageWrapperTwo).setRaised(principalTokens[i], raised[i]);

    }

    emit LogSetCoinSetting(principalTokens, isERC20s, minAmounts, raised);

  }


  /// @notice  Set the Governance Wallet!
  ///
  /// @param   newGovernanceWallet - The address of the new Governance Wallet
  function setGovernanceWallet(address newGovernanceWallet) external notDeprecated {

    // require the msg.sender either be Governance Wallet or an Assistant Wallet
    require(
      msg.sender == _storage.getGovernanceWallet() ||
      assistants[msg.sender] == true,
      "#Admin setGovernanceWallet(): Only Governance or Assistant wallets can access this."
    );

    StorageWrapper(_storage.getContractAddress(STORAGE_WRAPPER_CONTRACT)).setGovernanceWallet(newGovernanceWallet);

    emit LogSetGovernanceWallet(newGovernanceWallet);

  }


  /// @notice  Add or remove a StorageWrapper contract to storage
  ///
  /// @dev     Approved Storage Wrappers have access to mutate Storage contract
  ///
  ///          This isn't necessarily a contract, could be an EOA
  ///
  /// @param   theStorageWrapper - The contract address to set
  /// @param   action - Set or remove / true or false
  function setStorageWrapperContract(
    address theStorageWrapper,
    bool action
  )
    external
    notDeprecated
    onlyGovernance
  {

    StorageWrapper(_storage.getContractAddress(STORAGE_WRAPPER_CONTRACT)).setStorageWrapperContract(theStorageWrapper, action);

    emit LogSetStorageWrapper(theStorageWrapper, action);

  }


  /// @notice  Add or remove an Assistant Wallet locally
  ///
  /// @dev     Approved Assistants can set the Governance wallet
  ///
  ///          This isn't necessarily an EOA, could be a contract
  ///
  /// @param   theAssistant - The assistant wallet address to set
  /// @param   action - Add or remove / true or false
  function setAssistantWallet(
    address theAssistant,
    bool action
  )
    external
    notDeprecated
    onlyGovernance
  {

    assistants[theAssistant] = action;

    emit LogSetAssistantWallet(theAssistant, action);

  }


  /// @notice  Add or remove a Rate Modifier locally
  ///
  /// @dev     Approved Rate Modifier can set the benchmark rate
  ///
  ///          This isn't necessarily an EOA, could be a contract
  ///
  ///          This is temporary, used to avoid having our Governance wallet hot
  ///          while we're in a more centralized state.
  ///
  /// @param   rateModifier - The rate modifier address to set
  /// @param   action - Set or remove / true or false
  function setRateModifier(
    address rateModifier,
    bool action
  )
    external
    notDeprecated
    onlyGovernance
  {

    rateModifiers[rateModifier] = action;

    emit LogSetRateModifier(rateModifier, action);

  }


  /// @notice  Set the portfolios to a contract address (in case we wish to support multiple versions)
  ///
  /// @dev     Indexes need to correspond
  ///
  /// @param   portfolioKeys - The portfolio keys to map to the contract
  /// @param   contractAddresses - The contract address to be mapped to
  ///
  /// TODO:    Change from portfolioKeys to keys - Opportunity keys also get inputted here
  function setVerifier(
    bytes32[] memory portfolioKeys,
    address[] memory contractAddresses
  )
    public // not using external b/c use memory to pass in array
    notDeprecated
    onlyGovernance
  {

    address storageWrapper = _storage.getContractAddress(STORAGE_WRAPPER_CONTRACT);

    for (uint i = 0; i < portfolioKeys.length; i++) {

      // we're over-writing a contract, can be valid - ex. deprecating an Opportunity
      // contract we don't have the local variable "deprecated" in them. The only reference
      // internally the system has to an Opportunities address is the mapping of an
      // opportunity key to opportunity address in Verifier. Erase this and the
      // contract doesn't 'exist' in the system anymore, therefore deprecating it.
      // We do still enter externally Opportunity addresses through the Oracle.
      // All those calls filter through the OpportunityManager though which checks that the
      // opportunity key entered maps to the opportunity address entered.
      // Setting an opportunity key to NULL_ADDRESS is valid too, if we don't have
      // a replacement contract but we do want to deprecate it.
      address currentAddress = _storage.getVerifier(portfolioKeys[i]);

      if (currentAddress != NULL_ADDRESS) {

        emit LogOverwriteInVerifier(portfolioKeys[i], currentAddress, contractAddresses[i]);

      }

      StorageWrapper(storageWrapper).setVerifier(portfolioKeys[i], contractAddresses[i]);

    }

    emit LogSetVerifier(portfolioKeys, contractAddresses);

  }


  /// @notice  Helper function for Entrypoint contract, auto upgrade user tokens
  ///          when we come out with a new update. Ex. new portfolio
  ///
  /// @dev     Not using external b/c use memory to pass in array
  ///
  /// @param   tokenIds - The token id's to upgrade
  function upgradeTokens(bytes32[] memory tokenIds) public notDeprecated onlyGovernance {

    Entrypoint(_storage.getContractAddress(ENTRYPOINT_CONTRACT)).upgradeTokens(tokenIds);

    emit LogUpgradeTokens(tokenIds);

  }


  /// @notice  Helper function to configure new coins for Compound / Bzx
  ///
  /// @dev      Indexes need to correspond
  ///
  /// @param    opportunity - The adddress of the Opportunity to add to
  /// @param    principalTokens - The coins to add
  /// @param    contracts - The contracts the coins map to for the Opportunity
  function addMarketByContract(
    address opportunity,
    address[] memory principalTokens,
    address[] memory contracts
  )
    public // not using external b/c use memory to pass in array
    notDeprecated
    onlyGovernance
  {

    // could add check that verifies opportunity isn't deprecated since we
    // no longer check in the Opportunity itself
    MarketByContract(opportunity).addPrincipalTokens(principalTokens, contracts);

    emit LogAddMarketByContract(opportunity, principalTokens, contracts);

  }


  /// @notice  Helper function to configure new coins for Dydx
  ///
  /// @dev      Indexes need to correspond
  ///
  ///           IDs: 0 == ETH, 1 == DAI, 2 == USDC (for dYdX)
  ///
  /// @param    opportunity - The adddress of the Opportunity to add to
  /// @param    primaryIds - dydx term, the id is tied to a coin
  /// @param    secondaryIds - dydx term, the id is tied to a coin
  function addMarketByNumber(
    address opportunity,
    address[] memory principalTokens,
    uint[] memory primaryIds,
    uint[] memory secondaryIds
  )
    public // not using external b/c use memory to pass in array
    notDeprecated
    onlyGovernance
  {

    // could add check that verifies opportunity isn't deprecated since we
    // no longer check in the Opportunity itself
    MarketByNumber(opportunity).addPrincipalTokens(principalTokens, primaryIds, secondaryIds);

    emit LogAddMarketByNumber(opportunity, principalTokens, primaryIds, secondaryIds);

  }


  /// @notice  Set a contract's deprecated status
  ///
  /// @param   theContract - The contract to deprecate/or un-deprecate
  /// @param   status - Deprecate or un-deprecate / true or false
  function setContractDeprecationStatus(
    address theContract,
    bool status
  )
    external
    notDeprecated
    onlyGovernance
  {

    Upgradeable(theContract).setDeprecated(status);

    emit LogSetDeprecatedStatus(theContract, status);

  }


  /// @notice  Withdraw the ACP Contribution
  ///
  /// @param   key - The portfolio key we're withdrawing from
  ///
  /// TODO: Group the ACP Contribution so we can withdraw all at once per coin
    function claimACPContribution(bytes32 key) external notDeprecated onlyGovernance {

        address principalAddress = _storage.getPrincipalAddress(key); // passing in is more gas friendly but opens up to user error

        // prevent potential re-entrancy from us to steal funds
        uint bufferProfitValue = _storage.getACPContribution(principalAddress);
        StorageWrapperTwo(_storage.getContractAddress(STORAGE_WRAPPER_TWO_CONTRACT)).setACPContribution(key, 0); // key is just one of the portfolios associated with this principal address

        if (bufferProfitValue > 0) {

          IPortfolioManager(_storage.getVerifier(key)).transferFunds(key, _storage.getGovernanceWallet(), bufferProfitValue);

          emit LogClaimFees(key, bufferProfitValue);

        }

    }


    /// @notice  Set status of an off-chain Oracle, giving it the ability to call the Oracle contract
    ///
    /// @param  oracles - The addresses to modify access for
    /// @param  actions - Add or remove / true or false
    function setOracle(
      address[] memory oracles,
      bool[] memory actions
    )
      public // not using external b/c use memory to pass in array
      notDeprecated
      onlyGovernance
    {

      for (uint i = 0; i < oracles.length; i++) {

        StorageWrapperTwo(_storage.getContractAddress(STORAGE_WRAPPER_TWO_CONTRACT)).setOracle(oracles[i], actions[i]);

        emit LogSetOracle(oracles[i], actions[i]);

      }

    }


    /// @notice  Used to withdraw value from an Opportunity when it is to be
    ///          upgraded.
    ///
    /// @param   key - The portfolio key
    /// @param   opportunityKey - The opportunity key
    /// @param   opportunity - The opportunity to withdraw from
    /// @param   value - The value to withdraw (include insurance dust)
    function withdrawForUpgrade(
      bytes32 key,
      bytes32 opportunityKey,
      address opportunity,
      uint value
    )
      external
      notDeprecated
      onlyGovernance
    {

      Oracle(_storage.getContractAddress(ORACLE_CONTRACT)).withdraw(key, opportunityKey, opportunity, value);

      emit LogWithdrawForUpgrade(key, opportunityKey, opportunity, value);

    }


    /// @notice  Sets the deprecated flag of the contract
    ///
    /// @dev     Used when upgrading a contract
    ///
    /// @param   value - true to deprecate, false to un-deprecate
    function setDeprecated(bool value) external onlyGovernance {

        deprecated = value;

        emit LogSetDeprecatedAdmin(value);
    }


}
