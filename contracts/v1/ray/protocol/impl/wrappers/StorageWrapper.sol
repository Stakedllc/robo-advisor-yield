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

contract StorageWrapper is Upgradeable {


  /*************** STORAGE VARIABLE DECLARATIONS **************/


  // contracts used
  bytes32 internal constant FEE_MODEL_CONTRACT = keccak256("FeeModelContract");
  bytes32 internal constant ADMIN_CONTRACT = keccak256("AdminContract");
  bytes32 internal constant POSITION_MANAGER_CONTRACT = keccak256("PositionManagerContract");
  bytes32 internal constant OPPORTUNITY_MANAGER_CONTRACT = keccak256("OpportunityManagerContract");
  bytes32 internal constant ORACLE_CONTRACT = keccak256("OracleContract");
  bytes32 internal constant NAV_CALCULATOR_CONTRACT = keccak256("NAVCalculatorContract");

  IStorageWrapper public _storage;
  bool public deprecated;


  /*************** MODIFIER DECLARATIONS **************/


  /// @dev  A modifier that ensures the contract calling is allowed to mutate our Storage.
  modifier onlyRAYProtocolContracts(bytes32 contractId)
  {
      require(
           _storage.getVerifier(contractId) == msg.sender ||
           _storage.getContractAddress(POSITION_MANAGER_CONTRACT) == msg.sender ||
           _storage.getContractAddress(OPPORTUNITY_MANAGER_CONTRACT) == msg.sender ||
           _storage.getContractAddress(FEE_MODEL_CONTRACT) == msg.sender ||
           _storage.getContractAddress(ADMIN_CONTRACT) == msg.sender ||
           _storage.getContractAddress(NAV_CALCULATOR_CONTRACT) == msg.sender || // for updateYield()
           _storage.getContractAddress(ORACLE_CONTRACT) == msg.sender,
          "#StorageWrapper onlyRAYProtocolContracts Modifier: This is not a valid contract calling"
      );

      _;
  }


  /// @dev  A modifier that restricts functions that accept value not added to
  ///       or lent out of the contract.
  modifier notDeprecated()
  {
      require(
           deprecated == false,
          "#StorageWrapperTwo notDeprecated Modifier: In deprecated mode - this contract has been deprecated"
      );

      _;
  }


  /// @dev  A modifier that restricts functions to only be called by Admin Contract
  modifier onlyAdmin()
  {
      require(
        _storage.getContractAddress(ADMIN_CONTRACT) == msg.sender,
          "#StorageWrapper onlyAdmin Modifier: Only Admin can call this"
      );

      _;
  }


  /////////////////////// FUNCTION DECLARATIONS BEGIN ///////////////////////

  /******************* PUBLIC FUNCTIONS *******************/


  constructor(address __storage) public {

    _storage = IStorageWrapper(__storage);

  }


  /** ----------------- ONLY ADMIN MUTATORS ----------------- **/


  function setGovernanceWallet(
    address newGovernanceWallet
  )
    external
    notDeprecated
    onlyAdmin
  {

    _storage.setGovernanceWallet(newGovernanceWallet);

  }


  function setStorageWrapperContract(
    address theStorageWrapper,
    bool action
  )
    external
    notDeprecated
    onlyAdmin
  {

    _storage.setStorageWrapperContract(theStorageWrapper, action);

  }


  function setVerifier(
    bytes32 ray,
    address contractAddress
  )
    external
    notDeprecated
    onlyAdmin
  {

    _storage.setVerifier(ray, contractAddress);

  }


  function addOpportunity(
    bytes32 ray,
    bytes32 opportunityKey,
    address principalAddress
  )
    external
    notDeprecated
    onlyAdmin
  {

    _storage.addOpportunity(ray, opportunityKey, principalAddress);

  }


  function setValidOpportunity(
    bytes32 ray,
    bytes32 opportunityKey
  )
    external
    notDeprecated
    onlyAdmin
  {

    _storage.setValidOpportunity(ray, opportunityKey);

  }


  function setPausedOn(bytes32 ray) external notDeprecated onlyAdmin {

    _storage.setPausedOn(ray);

  }


  function setPausedOff(bytes32 ray) external notDeprecated onlyAdmin {

    _storage.setPausedOff(ray);

  }


  /**
  * We deprecate old contracts in the system. We have explicit revert flags on
  * functions that accept value and set storage
  *
  * NOTE: Used to have sepearte functions for setting deprecated on and off
  * to avoid user error but due to out of gas errors on deployment this has
  * been reduced to one function.
  */
  function setDeprecated(bool value) external onlyAdmin {

      deprecated = value;

  }


  /** ----------------- ONLY PROTOCOL CONTRACTS MUTATORS ----------------- **/


 function setTokenShares(
   bytes32 ray,
   bytes32 tokenId,
   uint tokenShares
 )
  external
  notDeprecated
  onlyRAYProtocolContracts(ray)
{

   _storage.setTokenShares(ray, tokenId, tokenShares);

 }


 function setTokenCapital(
   bytes32 ray,
   bytes32 tokenId,
   uint tokenCapital
 )
  external
  notDeprecated
  onlyRAYProtocolContracts(ray)
{

   _storage.setTokenCapital(ray, tokenId, tokenCapital);

 }


 function setShareSupply(
   bytes32 ray,
   uint newShareSupply
 )
  external
  notDeprecated
  onlyRAYProtocolContracts(ray)
{

   _storage.setShareSupply(ray, newShareSupply);

 }


 function setPrincipal(
   bytes32 opportunityKey,
   uint principalAmount
 )
  external
  notDeprecated
  onlyRAYProtocolContracts(opportunityKey)
{

   _storage.setPrincipal(opportunityKey, principalAmount);

 }


 function setRealizedYield(
   bytes32 ray,
   uint newRealizedYield
 )
  external
  notDeprecated
  onlyRAYProtocolContracts(ray)
{

   _storage.setRealizedYield(ray, newRealizedYield);

 }


 function setWithdrawnYield(
   bytes32 ray,
   uint newWithdrawnYield
 )
  external
  notDeprecated
  onlyRAYProtocolContracts(ray)
{

   _storage.setWithdrawnYield(ray, newWithdrawnYield);

 }

}
