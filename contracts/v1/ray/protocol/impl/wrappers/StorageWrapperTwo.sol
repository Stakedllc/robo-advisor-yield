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
import "../../interfaces/IStorageWrapper.sol";
import "../../interfaces/Upgradeable.sol";


/// @notice  One of the two (currently) contracts that have access to mutate
///          Storage
///
/// @dev     We abstracted the permissions logic from Storage contract into
///          this contract since we mean for Storage to be eternal. We can't
///          hold any logic in Eternal Storage in case we wish to change it.
///
///          Therefore we created Storage Wrappers. Essentially they just route
///          calls through to Storage, while verifying the caller.  Now if we wish
///          to upgrade the permissions logic we simply replace this wrapper.
///
///          Having it all in one contract was too large of a bytecode size to
///          deploy :/
///
/// Author:  Devan Purhar
/// Version  1.0.0

contract StorageWrapperTwo is Upgradeable {


  /*************** STORAGE VARIABLE DECLARATIONS **************/


  // contracts used
  bytes32 internal constant FEE_MODEL_CONTRACT = keccak256("FeeModelContract");
  bytes32 internal constant ADMIN_CONTRACT = keccak256("AdminContract");
  bytes32 internal constant POSITION_MANAGER_CONTRACT = keccak256("PositionManagerContract");
  bytes32 internal constant OPPORTUNITY_MANAGER_CONTRACT = keccak256("OpportunityManagerContract");
  bytes32 internal constant ORACLE_CONTRACT = keccak256("OracleContract");

  IStorageWrapper public _storage;
  bool public deprecated;


  /*************** MODIFIER DECLARATIONS **************/


  /**
  * dev A modifier that ensures the contract calling is allowed to access our _commonStorage.
  *
  * todo: define this in a different contract, not here
  */
  modifier onlyRAYProtocolContracts(bytes32 contractId)
  {
      require(
           _storage.getVerifier(contractId) == msg.sender ||
           _storage.getContractAddress(POSITION_MANAGER_CONTRACT) == msg.sender ||
           _storage.getContractAddress(OPPORTUNITY_MANAGER_CONTRACT) == msg.sender ||
           _storage.getContractAddress(FEE_MODEL_CONTRACT) == msg.sender ||
           _storage.getContractAddress(ADMIN_CONTRACT) == msg.sender ||
           _storage.getContractAddress(ORACLE_CONTRACT) == msg.sender,
          "#StorageWrapper onlyRAYProtocolContracts Modifier: This is not a valid contract calling"
      );

      _;
  }


  /**
  * dev A modifier that restricts functions to only be called by Admin
  *
  * todo: define this in a different, contract not in here
  */
  modifier onlyAdmin()
  {
      require(
        _storage.getContractAddress(ADMIN_CONTRACT) == msg.sender,
          "#StorageWrapper onlyAdmin Modifier: Only Admin can call this"
      );

      _;
  }


  /**
  * dev A modifier that restricts functions to only be called by FeeModel
  */
  modifier onlyFeeModel()
  {
      require(
        _storage.getContractAddress(FEE_MODEL_CONTRACT) == msg.sender,
          "#StorageWrapper onlyFeeModel Modifier: Only FeeModel can call this"
      );

      _;
  }


  /**
  * dev A modifier that restricts functions that accept value
  * not added to or lent out of the contract. Different from Pause b/c this is
  * local to the contract, not global to the system.
  */
  modifier notDeprecated()
  {
      require(
           deprecated == false,
          "#StorageWrapperTwo notDeprecated Modifier: In deprecated mode - this contract has been deprecated"
      );

      _;
  }

  /////////////////////// FUNCTION DECLARATIONS BEGIN ///////////////////////

  /******************* PUBLIC FUNCTIONS *******************/


  constructor(address __storage) public {

    _storage = IStorageWrapper(__storage);

  }


  /** ----------------- ONLY ADMIN MUTATORS ----------------- **/


  function setPrincipalAddress(
    bytes32 ray,
    address principalAddress
  )
    external
    notDeprecated
    onlyAdmin
  {

    _storage.setPrincipalAddress(ray, principalAddress);

  }


  function setMinAmount(
    address principalAddress,
    uint _minAmount
  )
    external
    notDeprecated
    onlyAdmin
  {

    _storage.setMinAmount(principalAddress, _minAmount);

  }


  function setRaised(
    address principalAddress,
    uint _raised
  )
    external
    notDeprecated
    onlyAdmin
  {

    _storage.setRaised(principalAddress, _raised);

  }


  function setIsERC20(
    address principalAddress,
    bool _isERC20
  )
    external
    notDeprecated
    onlyAdmin
  {

    _storage.setIsERC20(principalAddress, _isERC20);

  }


  function setOracle(
    address oracle,
    bool action
  )
    external
    notDeprecated
    onlyAdmin
  {

    _storage.setOracle(oracle, action);

  }


  function setContractAddress(
    bytes32 contractName,
    address contractAddress
  )
    external
    notDeprecated
    onlyAdmin
  {

    _storage.setContractAddress(contractName, contractAddress);

  }


  function setBenchmarkRate(
    address principalAddress,
    uint newRate
  )
    external
    notDeprecated
    onlyAdmin
  {

    _storage.setBenchmarkRate(principalAddress, newRate);

  }


  function setCumulativeRate(
    address principalAddress,
    uint newCumulativeRate
  )
    external
    notDeprecated
    onlyFeeModel
  {

    _storage.setCumulativeRate(principalAddress, newCumulativeRate);

  }


  function setLastUpdatedRate(
    address principalAddress,
    uint newLastUpdatedRate
  )
    external
    notDeprecated
    onlyFeeModel
  {

    _storage.setLastUpdatedRate(principalAddress, newLastUpdatedRate);

  }


  function setTokenAllowance(
    bytes32 ray,
    bytes32 tokenId,
    uint tokenAllowance
  )
   external
   notDeprecated
   onlyFeeModel
 {

    _storage.setTokenAllowance(ray, tokenId, tokenAllowance);

  }


  /**
  * We deprecate old contracts in the system. We have explicit revert flags on
  * functions that accept value and set the Storage contracts address to the null
  * address so it won't properly reference anything. This way nobody loses value
  * if they send it to our functions (not including fallback function), and
  * nobody will receive proper info from our other functions.
  *
  * NOTE: Used to have sepearte functions for setting deprecated on and off
  * to avoid user error but due to out of gas errors on deployment this has
  * been reduced to one function.
  */
  function setDeprecated(bool value) external onlyAdmin {

      deprecated = value;

  }


  /** ----------------- ONLY PROTOCOL CONTRACTS MUTATORS ----------------- **/


  function setACPContribution(
    bytes32 ray,
    uint newACPContribution
  )
    external
    notDeprecated
    onlyRAYProtocolContracts(ray)
  {

    address principalAddress = _storage.getPrincipalAddress(ray);

    // save profit by coin type to make it easier to claim, rather then by portfolio type
    _storage.setACPContribution(principalAddress, newACPContribution);

  }


  function setAvailableCapital(
    bytes32 ray,
    uint newAvailableCapital
  )
    external
    notDeprecated
    onlyRAYProtocolContracts(ray)
  {

    _storage.setAvailableCapital(ray, newAvailableCapital);

  }


  function setEntryRate(
    bytes32 ray,
    bytes32 tokenId,
    uint entryRate
  )
    external
    notDeprecated
    onlyRAYProtocolContracts(ray)
  {

    _storage.setEntryRate(ray, tokenId, entryRate);

  }


  function setTokenKey(
    bytes32 tokenId,
    bytes32 ray
  )
    external
    notDeprecated
    onlyRAYProtocolContracts(ray)
  {

    _storage.setTokenKey(tokenId, ray);

  }


  function deleteTokenValues(
    bytes32 ray,
    bytes32 tokenId
  )
    external
    notDeprecated
    onlyRAYProtocolContracts(ray)
  {

    _storage.deleteTokenValues(ray, tokenId);

  }


  function setOpportunityToken(
    bytes32 ray,
    bytes32 opportunity,
    bytes32 tokenId
  )
    external
    notDeprecated
    onlyRAYProtocolContracts(ray)
  {

    _storage.setOpportunityToken(ray, opportunity, tokenId);

  }

}
