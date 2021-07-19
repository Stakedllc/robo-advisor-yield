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
import "../../interfaces/IRAYToken.sol";
import "../../interfaces/Upgradeable.sol";

import "../Storage.sol";


/// @notice  The only contract with permission to directly call the Token contracts
///          RAYT and RAY Opportunity Token (RAYOT)
///
/// @dev     We abstracted the permission logic from the token contracts to this
///          since we mean for the tokens to be eternal, so if we
///          wanted to change permissions logic to the tokens mutator functions
///          it would be impossible without new token contract(s).
///
///          Therefore we created Token Wrapper. Essentially it just route
///          calls through to RAY Tokens, while verifying the caller.  Now if
///          we wish to upgrade the permissions logic we simply replace this wrapper.
///
/// Author:  Devan Purhar
/// Version: 1.0.0

contract TokenWrapper is Upgradeable {


  /*************** STORAGE VARIABLE DECLARATIONS **************/


  // contracts used
  bytes32 internal constant POSITION_MANAGER_CONTRACT = keccak256("PositionManagerContract");
  bytes32 internal constant ADMIN_CONTRACT = keccak256("AdminContract");

  Storage public _storage;
  bool public deprecated;


  /*************** MODIFIER DECLARATIONS **************/


  /// @dev  A modifier that restricts functions to only be called by RAY's PositionManager
  modifier onlyPositionManager()
  {
      require(
          _storage.getContractAddress(POSITION_MANAGER_CONTRACT) == msg.sender,
          "#TokenWrapper onlyPositionManager Modifier: Only Token Handler can call this"
      );

      _;
  }


  /// @dev  A modifier that restricts functions to only be called by Admin
  modifier onlyAdmin()
  {

    require(
      _storage.getContractAddress(ADMIN_CONTRACT) == msg.sender,
      "#TokenWrapper onlyAdmin Modifier(): Only the Admin Contract can call this"
    );

    _;

  }


  /// @dev  A modifier that restricts functions that accept value not added to
  ///       or lent out of the contract.
  modifier notDeprecated()
  {
      require(
           deprecated == false,
          "#TokenWrapper notDeprecated Modifier: In deprecated mode - this contract has been deprecated"
      );

      _;
  }


  /////////////////////// FUNCTION DECLARATIONS BEGIN ///////////////////////

  /******************* PUBLIC FUNCTIONS *******************/


  constructor(address __storage) public {

    _storage = Storage(__storage);

  }


  /** --------------- TOKEN WRAPPER ENTRYPOINTS ----------------- **/


  function mintRAYToken(
    bytes32 key,
    address beneficiary,
    address token
  )
    external
    notDeprecated
    onlyPositionManager
    returns(bytes32)
  {

    bytes32 tokenId = IRAYToken(token).mintRAYToken(key, beneficiary);

    return tokenId;

  }


  /** ----------------- ONLY ADMIN MUTATORS ----------------- **/


 function setDeprecated(bool value) external onlyAdmin {

     deprecated = value;

 }


}
