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
import "../openzeppelin/ERC721/IERC721Receiver.sol";
import "../openzeppelin/ERC20/IERC20.sol";

// internal dependencies
import "../../interfaces/RAY.sol";
import "../../interfaces/IRAYToken.sol";
import "../../interfaces/INAVCalculator.sol";

import "../Storage.sol";


/// @notice  Entrypoint is a wrapper and acts as the shared owner of a Ray Token to
///          enable different UX functionality such as auto-upgrading tokens, etc.
///
/// Author:  Devan Purhar
/// Version: 1.0.0

contract Entrypoint is IERC721Receiver {


  /*************** VARIABLE DECLARATIONS **************/


  // contracts used
  bytes32 internal constant ADMIN_CONTRACT = keccak256("AdminContract");
  bytes32 internal constant PAYER_CONTRACT = keccak256("PayerContract");
  bytes32 internal constant RAY_TOKEN_CONTRACT = keccak256("RAYTokenContract");
  bytes32 internal constant NAV_CALCULATOR_CONTRACT = keccak256("NAVCalculatorContract");

  address internal constant NULL_ADDRESS = address(0);

  Storage public _storage;


  struct RAYToken {

    address beneficiary;
    bytes32[] upgradeKeys;

  }

  mapping(bytes32 => RAYToken) rayTokens;
  mapping(bytes32 => RAYToken) pendingRayTokens;

  // test dependencies
  mapping(address => bytes32) public tokenIds;


  /*************** EVENT DECLARATIONS **************/


  event LogPurchaseRAYT(
      bytes32 indexed tokenId,
      address indexed beneficiary,
      uint capital
  );


  /// @notice  Logs the upgrades a token has opted into
  event LogTokenPortfolioUpgrades(
    bytes32 indexed tokenId,
    bytes32[] upgrades // should index this, check if can with this Solidity version
  );


  /// @notice  Logs when the upgrade is complete per token
  event LogUpgradeComplete(
    bytes32 indexed tokenId,
    bytes32 indexed upgrade
  );

  /// @notice  Logs when a RAYT is pending...
  event LogPendingRayToken(
    bytes32 indexed tokenId
  );


  /*************** MODIFIER DECLARATIONS **************/

  /**
  * dev A modifier that restricts functions to only be called by Admin
  */
  modifier onlyAdmin()
  {
      require(
          msg.sender == _storage.getContractAddress(ADMIN_CONTRACT),
          "#Entrypoint onlyAdmin Modifier: Only Admin can call this"
      );

      _;
  }


  /**
  * dev A modifier that verifies either the msg.sender == our Payer contract
  * and then the original caller is passed as a parameter (so check the original caller)
  * since we trust Payer. else msg.sender must be the true owner of the token.
  *
  * origCaller is the address that signed the transaction that went through Payer
  */
  modifier onlyTokenOwner(bytes32 tokenId, address origCaller)
  {
      if (msg.sender == _storage.getContractAddress(PAYER_CONTRACT)) {

        require(rayTokens[tokenId].beneficiary == origCaller,
                "#Entrypoint onlyTokenOwner modifier: The original caller is not the owner of the token");

      } else {

        require(rayTokens[tokenId].beneficiary == msg.sender,
                "#Entrypoint onlyTokenOwner modifier: The caller is not the owner of the token");

      }

      _;
  }


  /////////////////////// FUNCTION DECLARATIONS BEGIN ///////////////////////

  /******************* PUBLIC FUNCTIONS *******************/


  /**
  * dev Constructor of the contract. Initializes required addresses for dependency contracts
  *
  */
  constructor(
    address __storage
  )
      public
  {

    _storage = Storage(__storage);

  }


  /// @notice  Fallback function to receive Ether
  ///
  /// @dev     Required to receive Ether from NCController upon withdraws
  function() external payable {

  }


  /** --------------------- RAY ENTRYPOINTS --------------------- **/


  function mint(
    bytes32 key,
    address beneficiary,
    uint value,
    bytes32[] memory upgrades // could validate upgrade keys passed in are valid portfolios, if not, nothing happens but waste of user gas
  )
    public // not using external b/c use memory to pass in array
    payable
    returns(bytes32)
  {

    // verify the signed message etc. since we'll be sending this

    address rayContract = _storage.getVerifier(key);
    uint payableValue = verifyValue(key, msg.sender, value, rayContract);

    // we're the beneficiary/owner of this RAY (the point of this contract) if they wish to
    // have the option of upgrading automatically
    bytes32 tokenId = RAY(rayContract).mint.value(payableValue)(key, address(this), value); // payable value could be 0

    RAYToken memory rayToken = RAYToken(beneficiary, upgrades);
    rayTokens[tokenId] = rayToken;

    emit LogPurchaseRAYT(tokenId, beneficiary, value);
    emit LogTokenPortfolioUpgrades(tokenId, upgrades);

    // test dependency
    tokenIds[beneficiary] = tokenId;

    return tokenId;

  }


  // no restrictions on whose adding capital to whose tokens
  function deposit(bytes32 tokenId, uint value) external payable {

    // verify signer wished to add capital to this tokenId, value will be verified too
    // this is applicable if we're sending tx's for users or anyone but we're the real use-case

    bytes32 key = _storage.getTokenKey(tokenId);
    address rayContract = _storage.getVerifier(key);

    uint payableValue = verifyValue(key, msg.sender, value, rayContract);

    RAY(rayContract).deposit.value(payableValue)(tokenId, value);

  }

  // could do a check or take a param as a flag that says if they want all
  // the tokens value so we just burn it instead or redeem()
  function redeem(bytes32 tokenId, uint valueToWithdraw, address originalCaller) external onlyTokenOwner(tokenId, originalCaller) {

    // only owner of token or verify it's signed by owner of token can call this

    bytes32 key = _storage.getTokenKey(tokenId);
    address rayContract = _storage.getVerifier(key);

    uint valueAfterFee = RAY(rayContract).redeem(tokenId, valueToWithdraw, originalCaller); // this value won't be used in check since Payer isn't calling

    address beneficiary = rayTokens[tokenId].beneficiary;
    transferFunds(key, beneficiary, valueAfterFee);

  }


  function transferRayToken(
    bytes32 tokenId,
    address newBeneficiary,
    address originalCaller
  )
    external
    onlyTokenOwner(tokenId, originalCaller)
  {

    // only owner of token or verify it's signed by owner of token can call this

    rayTokens[tokenId].beneficiary = newBeneficiary;

    IRAYToken(_storage.getContractAddress(RAY_TOKEN_CONTRACT)).safeTransferFrom(address(this), newBeneficiary, uint(tokenId));

  }


  function optInUpgradesLater(
    bytes32 tokenId,
    bytes32[] memory upgrades,
    address originalCaller
  )
    public // not using external b/c use memory to pass in array
  {

    uint convertedTokenId = uint(tokenId);
    address beneficiary = IRAYToken(_storage.getContractAddress(RAY_TOKEN_CONTRACT)).ownerOf(convertedTokenId);

    if (msg.sender == _storage.getContractAddress(PAYER_CONTRACT)) {

      require(beneficiary == originalCaller,
      "#Entrypoint optinUpgradesLater: Original Caller was not the owner of this token");

    } else {

      require(beneficiary == msg.sender,
       "#Entrypoint optInUpgradesLater: Msg sender is not the owner of this token");

    }

    RAYToken memory rayToken = RAYToken(beneficiary, upgrades);
    pendingRayTokens[tokenId] = rayToken; // add to pending mapping until we confirm we recieved the Ray

    // could carry out rest of function in onERC721() but we'd be forced to use
    // some storage to cache what tokens we expect
    IRAYToken(_storage.getContractAddress(RAY_TOKEN_CONTRACT)).safeTransferFrom(beneficiary, address(this), convertedTokenId);

    emit LogPendingRayToken(tokenId);

  }


  function onERC721Received
  (
      address /*operator*/,
      address /*from*/,
      uint256 tokenId,
      bytes /*data*/
  )
      public
      returns(bytes4)
  {

      bytes32 convertedTokenId = bytes32(tokenId);

      if (pendingRayTokens[convertedTokenId].beneficiary != NULL_ADDRESS) {

        rayTokens[convertedTokenId] = pendingRayTokens[convertedTokenId];

        delete pendingRayTokens[convertedTokenId];

        emit LogTokenPortfolioUpgrades(convertedTokenId, rayTokens[convertedTokenId].upgradeKeys);

      }

      return bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
  }


  /** ----------------- ONLY ADMIN MUTATORS ----------------- **/


  function upgradeTokens(bytes32[] _tokenIds) external onlyAdmin {

    for (uint i = 0; i < _tokenIds.length; i++) {

      bytes32 tokenToUpgrade = _tokenIds[i];

        // // it's cheaper to do this for loop in our use case then have another variable
        // // that tracks what index we're on (20,000 original creation + 5000 every update)
        // // also cheaper then re-shuffling the array
        // // 5 loops of the extra logic is ~5,000 so if it is expected to have 4 upgrades
        // // or less it's chepaer
        // for (uint j = 0; j < rayTokens[tokenToUpgrade].upgradeKeys.length; j++) {

      bytes32 upgrade = rayTokens[tokenToUpgrade].upgradeKeys[0];

      bytes32 newTokenId = upgradeToken(tokenToUpgrade, upgrade);

      // not in danger of re-entrancy since we only call trusted contracts in the above function
      updateRayToken(tokenToUpgrade, newTokenId);

        // }

    }

  }


  /************************ INTERNAL FUNCTIONS **********************/


  function verifyValue(
    bytes32 key,
    address funder,
    uint inputValue,
    address rayContract
  )
    internal
    returns(uint)
  {

    address principalAddress = _storage.getPrincipalAddress(key);

    if (_storage.getIsERC20(principalAddress)) {

      require(
        IERC20(principalAddress).transferFrom(funder, address(this), inputValue),
        "#Entrypoint verifyValue(): Transfer of ERC20 Token failed"
      );

      // should one time max approve the ray contract (or everytime it upgrades and changes addresses)
      require(
        IERC20(principalAddress).approve(rayContract, inputValue),
        "#Entrypoint verifyValue(): Approval of ERC20 Token failed"
      );

      return 0;

    } else {

      require(inputValue == msg.value, "#RAY verifyValue(): ETH value sent does not match input value");
      return inputValue;

    }

  }


  function transferFunds(bytes32 key, address beneficiary, uint value) internal {

    address principalAddress = _storage.getPrincipalAddress(key);

    if (_storage.getIsERC20(principalAddress)) {

      require(
        IERC20(principalAddress).transfer(beneficiary, value),
        "#Entrypoint transferFunds(): Transfer of ERC20 token failed"
    );

    } else {

      beneficiary.transfer(value);

    }

  }


  function upgradeToken(bytes32 tokenId, bytes32 upgrade) internal returns(bytes32) {

    uint tokenValue;
    uint pricePerShare;

    bytes32 key = _storage.getTokenKey(tokenId);
    address rayContract = _storage.getVerifier(key);

    (tokenValue, pricePerShare) = INAVCalculator(_storage.getContractAddress(NAV_CALCULATOR_CONTRACT)).getTokenValue(key, tokenId);

    uint valueAfterFee = RAY(rayContract).redeem(tokenId, tokenValue, address(0)); // withdraw out of old ray

    uint payableValue = setupPurchase(upgrade, rayContract, valueAfterFee);
    bytes32 newTokenId = RAY(rayContract).mint.value(payableValue)(upgrade, address(this), valueAfterFee); // payable value could be 0

    emit LogUpgradeComplete(tokenId, upgrade);

    return newTokenId;

  }


  function setupPurchase(bytes32 key, address rayContract, uint value) internal returns(uint) {

    address principalAddress = _storage.getPrincipalAddress(key);

    if (_storage.getIsERC20(principalAddress)) {

      // should one time max approve the ray contract (or everytime it upgrades and changes addresses)
      require(
        IERC20(principalAddress).approve(rayContract, value),
        "#Entrypoint setupPurchase(): Approval of ERC20 token failed"
      );

      return 0;

    } else {

      return value;

    }

  }


  function updateRayToken(bytes32 tokenId, bytes32 newTokenId) internal {

    rayTokens[newTokenId].beneficiary = rayTokens[tokenId].beneficiary;

    delete rayTokens[tokenId].upgradeKeys[0]; // sets the index to zero
    bytes32[] memory oldTokenUpgrades = rayTokens[tokenId].upgradeKeys;

    // start at 1 since spot 0 was just done
    // should just copy - the just done upgrade since every solution
    // requires us copying the arr, this one has a cheaper partner function in
    // upgradeTOkens
    for (uint i = 1; i < oldTokenUpgrades.length; i++) {

      rayTokens[newTokenId].upgradeKeys.push(oldTokenUpgrades[i]);

    }

    // test dependency
    tokenIds[rayTokens[newTokenId].beneficiary] = newTokenId;

    delete rayTokens[tokenId]; // re-coup some gas

  }


  /*************** TESTING FUNCTIONS (to be removed before public release) **************/


  /**
  * dev Gets the RAYT uuid for a given address
  *
  * NOTE: This is not a permanent function, just for testing. Usually clients get
  * their RAYT uuid's from emitted logs. Also this tracking system screws up when
  * more then one RAYT is owned by the same address.
  *
  * returns the RAYT uuid
  */
  function getTokenId() external view returns(bytes32)
  {
      return tokenIds[msg.sender];
  }


}
