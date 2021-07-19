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


/// @notice  Implementation of the Eternal Storage Pattern to enable the RAY
///          smart contracts system to be upgradable.
///
/// Author:  Devan Purhar
/// Version: 1.0.0

contract Storage {


  /*************** STORAGE VARIABLE DECLARATIONS **************/


  // TODO: remove 'wallet', this will eventually be a contract, not an EOA
  address public governanceWalletAddress;

  mapping(address => bool) internal storageWrappers; // verified addresses to mutate Storage
  mapping(address => bool) internal oracles; // verified off-chain addresses to call the Oracle contract
  mapping(bytes32 => address) internal verifier; // verified contract for portfolio impls.
  mapping(bytes32 => address) internal contracts; // verified contracts of the system
  mapping(bytes32 => bytes32) internal tokenKeys;
  mapping(bytes32 => CommonState) internal _commonStorage;
  mapping(bytes32 => PortfolioState) internal _portfolioStorage;
  mapping(address => CoinState) internal _coinStorage;


  /// @notice  Common state across RAY's and Opportunities
  struct CommonState {

    uint withdrawnYield;
    uint realizedYield;
    uint totalShareSupply;
    uint principal; // only used by Opportunities, only one principal balance to track per Opportunity pool
    bool pausedMode;
    address principalAddress;

    mapping(bytes32 => uint[4]) tokenValues;

    // include these for flexibility in the future
    mapping(bytes32 => bool) _bool;
    mapping(bytes32 => int) _int;
    mapping(bytes32 => uint) _uint;
    mapping(bytes32 => string) _string;
    mapping(bytes32 => address) _address;
    mapping(bytes32 => bytes) _bytes;

  }


  /// @notice Variables only Portfolios require
  struct PortfolioState {

    mapping(bytes32 => bytes32) opportunityTokens;
    bytes32[] opportunities;
    mapping(bytes32 => bool) validOpportunities;
    uint availableCapital;

  }


  /// @notice  State that needs to be filled out for a coin to be added to the
  ///          system.
  ///
  /// TODO:    Remove minAmount. We should go back to only enforcing the technical
  ///          minimal amount on-chain and leave any harder restrictions to GUI-side.
  ///          It's not in favor of an 'open' system to have minimum limits.
  struct CoinState {

    uint benchmarkRate;
    uint cumulativeRate;
    uint lastUpdatedRate; // in seconds
    uint acpContribution;
    uint minAmount;
    uint raised;
    bool isERC20;

  }


  /*************** MODIFIER DECLARATIONS **************/


  /// @notice  Checks the caller is a valid Storage Wrapper
  ///
  /// @dev     Only Storage Wrappers can mutate Storage's storage
  modifier onlyStorageWrappers()
  {
      require(
          storageWrappers[msg.sender] == true,
         "#Storage onlyStorageWrappers Modifier: Only StorageWrappers can call this"
      );

      _;
  }


  /////////////////////// FUNCTION DECLARATIONS BEGIN ///////////////////////

  /******************* PUBLIC FUNCTIONS *******************/


  /// @notice  Sets the Admin contract to our wallet originally until we deploy
  ///          the Admin contract (next step in deployment). Also sets our wallet
  ///          wallet address as a storage wrapper, later unsets it.
  ///
  /// @param   _governanceWalletAddress - governance's wallet address
  /// @param   _weth - Canonical WETH9 contract address
  /// @param   _dai - DAI token contract address
  constructor(
    address _governanceWalletAddress,
    address _weth,
    address _dai
  )
    public
  {

    governanceWalletAddress = _governanceWalletAddress;

    contracts[keccak256("WETHTokenContract")] = _weth;
    contracts[keccak256("DAITokenContract")] = _dai;
    contracts[keccak256("AdminContract")] = msg.sender; // need to deploy Admin and then forgo this

    storageWrappers[msg.sender] = true; // need to deploy and set Storage Wrappers then forgo this

  }


  /** ----------------- GLOBAL VIEW ACCESSORS ----------------- **/


  /// @notice  Gets the current governance address
  ///
  /// @return  governance address
  function getGovernanceWallet() external view returns (address) {

    return governanceWalletAddress;

  }


  /// @notice  Checks if the entered address is an approved Oracle
  ///
  /// @param   target - address we're checking out
  ///
  /// @return  true or false
  function getIsOracle(address target) external view returns (bool) {

    return oracles[target];

  }


  /// @notice  Gets a contract address by a bytes32 hash (keccak256)
  ///
  /// @param   contractName - Ex. keccak256("PortfolioManagerContract");
  ///
  /// @return  The contract address
  function getContractAddress(bytes32 contractName) external view returns (address) {

    return contracts[contractName];

  }


  /// @notice  Maps portfolio's to the contract that they currently are used
  ///          through. Supports multiple versions of the same contracts
  ///
  /// @param   contractName - Ex. keccak256("PortfolioManagerContract");
  ///
  /// @return  The contract address
  function getVerifier(bytes32 contractName) external view returns (address) {

    return verifier[contractName];

  }


  /// @notice  Each token is mapped to a key that unlocks everything for it
  ///          in storage.
  ///
  /// @param   tokenId - token id of the RAY token
  ///
  /// @return  The portfolio id/key associated
  function getTokenKey(bytes32 tokenId) external view returns (bytes32) {

    return tokenKeys[tokenId];

  }


  /** ----------------- STATE SPECIFIC-TYPE VIEW ACCESSOR ----------------- **/


  /// @notice  Get the Opportunities this portfolio is allowed to be in
  ///
  /// @param   portfolioId - the id of the portfolio
  ///
  /// @return  Array of valid opportunity id's
  function getOpportunities(bytes32 portfolioId) external view returns (bytes32[]) {

    return _portfolioStorage[portfolioId].opportunities;

  }


  /// @notice  Get's the coin type of the entered RAY
  ///
  /// @param   portfolioId - the id of the portfolio
  ///
  /// @return  The coin associated with the portfolio
  ///
  /// TODO:    Refactor to getPrincipalToken since we commonly use that
  function getPrincipalAddress(bytes32 portfolioId) external view returns (address) {

    return _commonStorage[portfolioId].principalAddress;

  }


  /// @notice  Check if the entered coin is an ERC20
  ///
  /// @param   principalAddress - the coin contract address we're checking
  ///
  /// @return  true or false
  function getIsERC20(address principalAddress) external view returns (bool) {

    return _coinStorage[principalAddress].isERC20;

  }

  /// @notice  Get the min. amount for the associated coin
  ///
  /// @param   principalAddress - the coin contract address we're checking
  ///
  /// @return  min. amount in smallest units in-kind
  ///
  /// TODO: Remove this (and refactor the check used in PositionManager associated)
  function getMinAmount(address principalAddress) external view returns (uint) {

    return _coinStorage[principalAddress].minAmount;

  }

  /// @notice  Get the normalizer factor for the associated coin
  ///
  /// @param   principalAddress - the coin contract address we're checking
  ///
  /// @return  multiplier to use on the input values for this coin
  function getRaised(address principalAddress) external view returns (uint) {

    return _coinStorage[principalAddress].raised;

  }


  /// @notice  Gets the current benchmark rate of associated coin
  ///
  /// @param   principalAddress - the coin contract address we're checking
  ///
  /// @return  benchmark rate
  function getBenchmarkRate(address principalAddress) external view returns (uint) {

    return _coinStorage[principalAddress].benchmarkRate;

  }


  /// @notice  Gets the cumulative rate of the portfolio entered
  ///
  /// @dev     The cumulative rate tracks how the benchmark rate has
  ///          progressed over time. Used in our fee model to find
  ///          what benchmark rate is appropriate to a unique token
  ///          based on when they joined and the changes the rate
  ///          went through in that time period before they withdraw.
  ///
  /// @param   principalAddress - the coin contract address we're checking
  ///
  /// @return  the cumulative benchmark rate
  function getCumulativeRate(address principalAddress) external view returns (uint) {
    return _coinStorage[principalAddress].cumulativeRate;
  }


  /// @notice  Gets the last time in seconds the cumulative rate was
  ///          was updated for the associated coin
  ///
  /// @param   principalAddress - the coin contract address we're checking
  ///
  /// @return  Last time in seconds the cumulative rate was updated
  function getLastUpdatedRate(address principalAddress) external view returns (uint) {
    return _coinStorage[principalAddress].lastUpdatedRate;
  }


  /// @notice  Gets the ACP Contribution for the associated coin
  ///
  /// @param   principalAddress - the coin contract address we're checking
  ///
  /// @return  the acp contribution
  function getACPContribution(address principalAddress) external view returns (uint) {

    return _coinStorage[principalAddress].acpContribution;

  }


  /// @notice  Checks if the opportunity is allowed for the associated portfolio
  ///
  /// @param   portfolioId - the id of the portfolio
  /// @param   opportunityId - the id of the opportunity
  ///
  /// @return  true or false
  function isValidOpportunity(bytes32 portfolioId, bytes32 opportunityId) external view returns (bool) {

   return _portfolioStorage[portfolioId].validOpportunities[opportunityId];

 }

  /// @notice  Get the shares of the associated token
  ///
  /// @param   portfolioId - the id of the portfolio
  /// @param   tokenId - the id of the token
  ///
  /// @return  the number of shares
  function getTokenShares(bytes32 portfolioId, bytes32 tokenId) external view returns (uint) {
    return _commonStorage[portfolioId].tokenValues[tokenId][0];
  }


  /// @notice  Get the capital of the associated token
  ///
  /// @param   portfolioId - the id of the portfolio
  /// @param   tokenId - the id of the token
  ///
  /// @return  the amount of capital
  function getTokenCapital(bytes32 portfolioId, bytes32 tokenId) external view returns (uint) {
    return _commonStorage[portfolioId].tokenValues[tokenId][1];
  }


  /// @notice  Gets the allowance of the associated token
  ///
  /// @dev     Each token has an allowance which reflects how much yield they're
  ///          able to make without being charged a fee by us.
  ///
  /// @param   portfolioId - the id of the portfolio
  /// @param   tokenId - the id of the token
  ///
  /// @return  the amount of allowance
  function getTokenAllowance(bytes32 portfolioId, bytes32 tokenId) external view returns (uint) {
    return _commonStorage[portfolioId].tokenValues[tokenId][2];
  }


  /// @notice  Gets the value of the cumulative rate the token 'entered' at.
  ///
  /// @dev     I say 'entered' because when a token adds capital or partially withdraws
  ///          or anytime it changes it's token capital we reset this.
  ///
  /// @param   portfolioId - the id of the portfolio
  /// @param   tokenId - the id of the token
  ///
  /// @return  the entry rate in seconds
  ///
  /// TODO:    Based on the above @dev we should refactor this to a more appropriate
  ///          name
  function getEntryRate(bytes32 portfolioId, bytes32 tokenId) external view returns (uint) {
    return _commonStorage[portfolioId].tokenValues[tokenId][3];
  }


  /// @notice  Gets the Opportunity Token of a portfolio.
  ///
  /// @dev     We assume a portfolio will only need one of a certain Opportunity
  ///          Token. It shouldn't ever need multiple of the same Opportunity.
  ///
  /// @param   portfolioId - the id of the portfolio
  /// @param   opportunityId - the id of the opportunity
  ///
  /// @return  The Opportunity token id
  function getOpportunityToken(bytes32 portfolioId, bytes32 opportunityId) external view returns (bytes32) {
    return _portfolioStorage[portfolioId].opportunityTokens[opportunityId];
  }


  /// @notice  Get the principal supplied for the Opportunity
  ///
  /// @param   opportunityId - the id of the opportunity
  ///
  /// @return  the amount of principal supplied
  function getPrincipal(bytes32 opportunityId) external view returns (uint) {
    return _commonStorage[opportunityId].principal;
  }


  /// @notice  Check if in paused mode for the associated portfolio
  ///
  /// @param   portfolioId - the id of the portfolio
  ///
  /// @return  true or false
  function getPausedMode(bytes32 portfolioId) external view returns (bool) {
    return _commonStorage[portfolioId].pausedMode;
  }


  /// @notice  Gets the realized yield of the associated portfolio
  ///
  /// @dev     Realized yield is the yield we've made, but withdrew
  ///          back into the system and now use it as capital
  ///
  /// @param   portfolioId - the id of the portfolio
  ///
  /// @return  the yield realized
  function getRealizedYield(bytes32 portfolioId) external view returns (uint) {
    return _commonStorage[portfolioId].realizedYield;
  }


  /// @notice  Gets the withdrawn yield of the associated portfolio
  ///
  /// @param   portfolioId - the id of the portfolio
  ///
  /// @return  the yield withdrawn
  function getWithdrawnYield(bytes32 portfolioId) external view returns (uint) {
    return _commonStorage[portfolioId].withdrawnYield;
  }


  /// @notice  Gets the available capital of the portfolio associated
  ///
  /// @dev     Available capital is the amount of funds available to a portfolio.
  ///          This is instantiated by users depositing funds
  ///
  /// @param   portfolioId - the id of the portfolio
  ///
  /// @return  the available capital
  function getAvailableCapital(bytes32 portfolioId) external view returns (uint) {
    return _portfolioStorage[portfolioId].availableCapital;
  }


  /// @notice  Gets the share supply of the portfolio associated
  ///
  /// @param   portfolioId - the id of the portfolio
  ///
  /// @return  the total shares
  function getShareSupply(bytes32 portfolioId) external view returns (uint) {
    return _commonStorage[portfolioId].totalShareSupply;
  }


  /** ----------------- GENERIC TYPE VIEW ACCESSOR ----------------- **/


  function getBoolean(bytes32 ray, bytes32 key) external view returns (bool) {
    return _commonStorage[ray]._bool[key];
  }


  function getInt(bytes32 ray, bytes32 key) external view returns (int) {
    return _commonStorage[ray]._int[key];
  }


 function getUint(bytes32 ray, bytes32 key) external view returns (uint) {
   return _commonStorage[ray]._uint[key];
  }


 function getAddress(bytes32 ray, bytes32 key) external view returns (address) {
   return _commonStorage[ray]._address[key];
 }


 function getString(bytes32 ray, bytes32 key) external view returns (string) {
   return _commonStorage[ray]._string[key];
 }


 function getBytes(bytes32 ray, bytes32 key) external view returns (bytes) {
   return _commonStorage[ray]._bytes[key];
 }


 /** ----------------- ONLY STORAGE WRAPPERS GLOBAL MUTATORS ----------------- **/


  /// @notice  This sets the Governance Wallet - important since this wallet controls
  ///          the Admin contract that controls 'Governance' in the system.
  ///
  /// @param   newGovernanceWallet - the new governance address
  function setGovernanceWallet(address newGovernanceWallet) external onlyStorageWrappers {

    governanceWalletAddress = newGovernanceWallet;

  }


  /// @dev Adds or remove an address to Oracle permissions status
  ///
  /// @param oracle - the address of the wallet targeted
  /// @param action - the action we wish to carry out, true to add, false to remove
  function setOracle(address oracle, bool action) external onlyStorageWrappers {

    oracles[oracle] = action;

  }


  /// @notice  Adds or removes an address to StorageWrapper permissions status
  ///
  /// @param  theStorageWrapper - the address to either add or remove
  /// @param  action - the action we wish to carry out, true to add, false to remove
  function setStorageWrapperContract(
    address theStorageWrapper,
    bool action
   )
    external
    onlyStorageWrappers
  {

    storageWrappers[theStorageWrapper] = action;

  }


  /// @notice  Sets a portfolio or opportunity to a contract implementation
  ///
  /// @param  typeId - the portfolio or opportunity id
  /// @param  contractAddress - the contract address
  function setVerifier(bytes32 typeId, address contractAddress) external onlyStorageWrappers {

    verifier[typeId] = contractAddress;

  }


  /// @notice  Sets the contract address mapped to a contracts name
  ///
  /// @param  contractName - The name of the contract
  /// @param  contractAddress - The address of the contract
  function setContractAddress(
    bytes32 contractName,
    address contractAddress
  )
    external
    onlyStorageWrappers
  {

    contracts[contractName] = contractAddress;

  }


  /// @notice  Sets a portfolio id to a token
  ///
  /// @param  tokenId - The id of the token
  /// @param  portfolioId - The id of the portfolio
  function setTokenKey(bytes32 tokenId, bytes32 portfolioId) external onlyStorageWrappers {

    tokenKeys[tokenId] = portfolioId;

  }


  /// @notice  Sets status on ERC20 for the associated coin
  ///
  /// @param  principalAddress - The coin's contract address
  /// @param  _isERC20 - true if is ERC20, false if not
  function setIsERC20(address principalAddress, bool _isERC20) external onlyStorageWrappers {

    _coinStorage[principalAddress].isERC20 = _isERC20;

  }


  /// @notice  Sets the min. amount for the associated coin
  ///
  /// @param  principalAddress - The coin's contract address
  /// @param  _minAmount - the min. amount in-kind smallest units
  function setMinAmount(address principalAddress, uint _minAmount) external onlyStorageWrappers {

    _coinStorage[principalAddress].minAmount = _minAmount;

  }


  /// @notice  Sets the normalizing multiplier for the associated coin
  ///
  /// @param  principalAddress - The coin's contract address
  /// @param  _raised - the multiplier
  function setRaised(address principalAddress, uint _raised) external onlyStorageWrappers {

    _coinStorage[principalAddress].raised = _raised;

  }


  /// @notice  Sets the benchmark rate for the associated coin
  ///
  /// @param  principalAddress - The coin's contract address
  /// @param  newBenchmarkRate - the new benchmark rate
  function setBenchmarkRate(
    address principalAddress,
    uint newBenchmarkRate
  )
    external
    onlyStorageWrappers
  {

    _coinStorage[principalAddress].benchmarkRate = newBenchmarkRate;

  }


  /// @notice  Sets the cumulative rate for the associated coin
  ///
  /// @param  principalAddress - The coin's contract address
  /// @param  newCumulativeRate - the new cumulative rate
  function setCumulativeRate(
    address principalAddress,
    uint newCumulativeRate
  )
    external
    onlyStorageWrappers
  {
    _coinStorage[principalAddress].cumulativeRate = newCumulativeRate;
  }


  /// @notice  Sets the timestamp for last updating the rate for the associated coin
  ///
  /// @param  principalAddress - The coin's contract address
  /// @param  newLastUpdatedRate - the new last updated rate
  function setLastUpdatedRate(
    address principalAddress,
    uint newLastUpdatedRate
  )
    external
    onlyStorageWrappers
  {
    _coinStorage[principalAddress].lastUpdatedRate = newLastUpdatedRate;
  }


  /// @notice  Sets the acp contribution for the associated coin
  ///
  /// @param  principalAddress - The coin's contract address
  /// @param  newACPContribution - the new acp contribution
  function setACPContribution(
    address principalAddress,
    uint newACPContribution
  )
    external
    onlyStorageWrappers
  {

    _coinStorage[principalAddress].acpContribution = newACPContribution;

  }


  /** ----------------- ONLY STORAGE WRAPPERS STATE SPECIFIC MUTATORS ----------------- **/


  /// @notice  Clears the data of the associated token (used upon a burn)
  ///
  /// @param  portfolioId - the id of the portfolio
  /// @param  tokenId - the id of the token
  function deleteTokenValues(bytes32 portfolioId, bytes32 tokenId) external onlyStorageWrappers {

    delete _commonStorage[portfolioId].tokenValues[tokenId];

  }


  /// @notice  Add an Opportunity to a portfolio's available options. We also set
  ///          the principal address used by the portfolio at the same time.
  ///
  /// @param   portfolioId - The id of the portfolio we're configuring
  /// @param   opportunityKey - The key of the opportunity we're adding to this portfolio
  /// @param   _principalAddress - The coin's contract address for this portfolio
  //
  /// TODO:    This is in-efficient, we set the principal address multiple times
  ///          for the same portfolio. Fix this.
  ///
  /// TODO:     Refactor principalToken -> principalAddress or opposite?
  function addOpportunity(
    bytes32 portfolioId,
    bytes32 opportunityKey,
    address _principalAddress
  )
    external
    onlyStorageWrappers
  {

    _portfolioStorage[portfolioId].opportunities.push(opportunityKey);
    _commonStorage[portfolioId].principalAddress = _principalAddress;

  }


  /// @notice  Set the principal address/coin of the associated portfolio
  ///
  /// @param   portfolioId - The id of the portfolio we're configuring
  /// @param   _principalAddress - The coin's contract address for this portfolio
  function setPrincipalAddress(
    bytes32 portfolioId,
    address _principalAddress
  )
    external
    onlyStorageWrappers
  {

    _commonStorage[portfolioId].principalAddress = _principalAddress;

  }


  /// @notice   Set an opportunity as valid in a mapping to a portfolio key
  ///
  /// @dev      We set the valid opportunities in an array, but we also set them
  ///           here for quicker access instead of having to iterate through the array.
  ///           Sacrifice the extra gas cost (20,000) per opportunity we 'double set'
  ///
  /// @param   portfolioId - the id of the portfolio
  /// @param   opportunityId - the id of the opportunity
  function setValidOpportunity(bytes32 portfolioId, bytes32 opportunityId) external onlyStorageWrappers {

   _portfolioStorage[portfolioId].validOpportunities[opportunityId] = true;

 }


  /// @notice  Set the shares of the associated token
  ///
  /// @param   portfolioId - The id of the portfolio we're configuring
  /// @param   tokenId - The id of the token we're configuring
  /// @param   tokenShares - The number of shares
  function setTokenShares(
    bytes32 portfolioId,
    bytes32 tokenId,
    uint tokenShares
  )
    external
    onlyStorageWrappers
  {
    _commonStorage[portfolioId].tokenValues[tokenId][0] = tokenShares;
  }


  /// @notice  Set the capital of the associated token
  ///
  /// @param   portfolioId - The id of the portfolio we're configuring
  /// @param   tokenId - The id of the token we're configuring
  /// @param   tokenCapital - The amount of capital
  function setTokenCapital(
    bytes32 portfolioId,
    bytes32 tokenId,
    uint tokenCapital
  )
    external
    onlyStorageWrappers
  {
    _commonStorage[portfolioId].tokenValues[tokenId][1] = tokenCapital;
  }


  /// @notice  Set the allowance of the associated token
  ///
  /// @param   portfolioId - The id of the portfolio we're configuring
  /// @param   tokenId - The id of the token we're configuring
  /// @param   tokenAllowance - The amount of allowance
  function setTokenAllowance(
    bytes32 portfolioId,
    bytes32 tokenId,
    uint tokenAllowance
  )
    external
    onlyStorageWrappers
  {
    _commonStorage[portfolioId].tokenValues[tokenId][2] = tokenAllowance;
  }


  /// @notice  Set the entry rate of the associated token
  ///
  /// @param   portfolioId - The id of the portfolio we're configuring
  /// @param   tokenId - The id of the token we're configuring
  /// @param   entryRate - The entry rate (in seconds)
  function setEntryRate(
    bytes32 portfolioId,
    bytes32 tokenId,
    uint entryRate
  )
    external
    onlyStorageWrappers
  {
    _commonStorage[portfolioId].tokenValues[tokenId][3] = entryRate;
  }


  /// @notice  Set the id of an Opportunity token for a portfolio
  ///
  /// @param   portfolioId - The id of the portfolio we're configuring
  /// @param   opportunityId - The id of the opportunity the token represents
  /// @param   tokenId - The id of the Opportunity token
  function setOpportunityToken(
    bytes32 portfolioId,
    bytes32 opportunityId,
    bytes32 tokenId
  )
    external
    onlyStorageWrappers
  {
    _portfolioStorage[portfolioId].opportunityTokens[opportunityId] = tokenId;
  }


  /// @notice  Set the id of an Opportunity token for a portfolio
  ///
  /// @param   opportunityId - The id of the opportunity the token represents
  /// @param   principalAmount - The new amount of principal
  function setPrincipal(
    bytes32 opportunityId,
    uint principalAmount
  )
    external
    onlyStorageWrappers
  {
    _commonStorage[opportunityId].principal = principalAmount;
  }


  /// @notice  Set paused mode on for a portfolio
  ///
  /// @dev     Enter keccak256("RAY") to pause all portfolios
  ///
  /// @param   portfolioId - The id of the portfolio we're configuring
  function setPausedOn(bytes32 portfolioId) external onlyStorageWrappers {
    _commonStorage[portfolioId].pausedMode = true;
  }


  /// @notice  Set paused mode off for a portfolio
  ///
  /// @dev     Enter keccak256("RAY") to un-pause all portfolios
  ///
  /// @param   portfolioId - The id of the portfolio we're configuring
  function setPausedOff(bytes32 portfolioId) external onlyStorageWrappers {
    _commonStorage[portfolioId].pausedMode = false;
  }


  /// @notice  Set the realized yield for a portfolio
  ///
  /// @param   portfolioId - The id of the portfolio we're configuring
  /// @param   newRealizedYield - The new realized yield
  function setRealizedYield(bytes32 portfolioId, uint newRealizedYield) external onlyStorageWrappers {
    _commonStorage[portfolioId].realizedYield = newRealizedYield;
  }


  /// @notice  Set the withdrawn yield for a portfolio
  ///
  /// @param   portfolioId - The id of the portfolio we're configuring
  /// @param   newWithdrawnYield - The new realized yield
  function setWithdrawnYield(bytes32 portfolioId, uint newWithdrawnYield) external onlyStorageWrappers {
    _commonStorage[portfolioId].withdrawnYield = newWithdrawnYield;
  }


  /// @notice  Set the available capital for a portfolio
  ///
  /// @param   portfolioId - The id of the portfolio we're configuring
  /// @param   newAvailableCapital - The new available capital
  function setAvailableCapital(bytes32 portfolioId, uint newAvailableCapital) external onlyStorageWrappers {
    _portfolioStorage[portfolioId].availableCapital = newAvailableCapital;
  }


  /// @notice  Set the total share supply for a portfolio
  ///
  /// @param   portfolioId - The id of the portfolio we're configuring
  /// @param   newShareSupply - The new share supply
  function setShareSupply(bytes32 portfolioId, uint newShareSupply) external onlyStorageWrappers {
    _commonStorage[portfolioId].totalShareSupply = newShareSupply;
  }


  /** ----------------- ONLY STORAGE WRAPPERS GENERIC MUTATORS ----------------- **/

  /// @notice  We have these to enable us to be flexible with our eternal storage
  ///          in the future. Also, we could always deploy a new Storage contract
  ///          and reference two Storage contracts in the system and so on.


  function setBoolean(bytes32 ray, bytes32 key, bool value) external onlyStorageWrappers {
    _commonStorage[ray]._bool[key] = value;
  }


  function setInt(bytes32 ray, bytes32 key, int value) external onlyStorageWrappers {
    _commonStorage[ray]._int[key] = value;
  }


 function setUint(bytes32 ray, bytes32 key, uint256 value) external onlyStorageWrappers {
   _commonStorage[ray]._uint[key] = value;
  }


 function setAddress(bytes32 ray, bytes32 key, address value) external onlyStorageWrappers {
   _commonStorage[ray]._address[key] = value;
 }


 function setString(bytes32 ray, bytes32 key, string value) external onlyStorageWrappers {
   _commonStorage[ray]._string[key] = value;
 }


 function setBytes(bytes32 ray, bytes32 key, bytes value) external onlyStorageWrappers {
   _commonStorage[ray]._bytes[key] = value;
 }


}
