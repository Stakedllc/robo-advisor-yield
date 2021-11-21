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
import "../openzeppelin/ERC721/ERC721Burnable.sol";
import "../openzeppelin/ERC721/ERC721Metadata.sol";

// internal dependencies
import "../Storage.sol";


/// @notice  RAYT are an ERC721 compatible token that represent a users 'stake' or
///         position in a particular RAY portfolio pool. That is, in the high-level pools.
///
/// @dev    The RAYT is meant to be eternal. We don't want to need to upgrade
///         the token contract which is why this is bare bones to the standard.
///         We prefer eternal token because it's better for interoperability. If
///         we upgrade our token contract, all third-party places we're listed
///         such as wallets or exchanges,  need to switch configurations too, it
///         gets confusing to track, etc.
///
///         As such, only the TokenWrapper can access the functions held here in
///         case we wish to change the permissions/logic access control on them
///
/// Author:  Devan Purhar
/// Version: 1.0.0
contract RAYToken is ERC721Burnable, ERC721Metadata {


  /*************** STORAGE VARIABLE DECLARATIONS **************/


    // contracts used
    bytes32 internal constant TOKEN_WRAPPER_CONTRACT = keccak256("TokenWrapperContract");

    Storage public _storage;
    uint internal salt;


    /*************** MODIFIER DECLARATIONS **************/


    /// @notice  Requires the caller is our TokenWrapper contract
    modifier onlyTokenWrapper()
    {
        require(
            _storage.getContractAddress(TOKEN_WRAPPER_CONTRACT) == msg.sender,
            "#RAYToken onlyTokenWrapper Modifier: Only Token Wrapper can call this"
        );

        _;
    }


    /////////////////////// FUNCTION DECLARATIONS BEGIN ///////////////////////

    /******************* PUBLIC FUNCTIONS *******************/


    /// @notice Constructs an ERC721 RAYT contract. Sets the name to be
    ///         "Robo Advisor for Yield" and the ticker to "RAY".
    ///
    /// @param   __storage - The Storage contracts address
    constructor(address __storage)
		  ERC721Metadata("Robo Advisor for Yield", "RAY")
		  public
	  {

      _storage = Storage(__storage);

    }


    /** ----------------- ONLY TOKEN WRAPPER MUTATORS ----------------- **/


    /// @notice  Mint the unique RAYT and insert it into the token registry.
    ///
    /// @dev     'key' is not currently used but I'm keeping it for now for
    ///           flexibility in the future
    ///
    /// @param   beneficiary is the investor whose receiving the minted token
    ///
    /// @return  the token id of the minted RAYT
    function mintRAYToken(
      bytes32 /*key*/,
      address beneficiary
    )
      external
      onlyTokenWrapper
      returns(bytes32)
    {

        salt++;
        bytes32 entryHash = createIssuanceHash(salt);

        super._mint(beneficiary, uint(entryHash));

        return entryHash;
    }


    /** ----------------- OVER-RIDDEN VIEW ACCESSORS ----------------- **/


    /// @notice  Gets the beneficiary/owner of the entered token.
    ///
    /// @dev     Simple wrapper over the ERC721 standard function. Not required
    ///          since it doesn't override it. Uses naming that better fits
    ///          our use-case but besides that doesn't add anything.
    ///
    /// @param   tokenId - The token's id we're trying to get the owner of
    ///
    /// @return  The beneficiary/owner of the entered token.
    function getBeneficiary(bytes32 tokenId)
    	external
    	view
    	returns(address)
    {
        return super.ownerOf(uint(tokenId));
    }


    /// @notice  Checks if a RAYT with the specified ID exists
    ///
    /// @dev     This is used to verify a token Id being entered for mutation
    ///          in other contracts RAYT exists, since it would be bad to
    ///          mutate storage of a RAYT yet to be minted (attack vector)
    ///
    ///          This is also a somewhat meaningless wrapper around the ERC721
    ///          standard function. Can be removed and refactor all to directly
    ///          call _exists.
    ///
    /// @param   tokenId - The id of the token we're checking's existence of
    ///
    /// @return  true if token does exist or false if doesn't
    function tokenExists(bytes32 tokenId)
      external
      view
      returns (bool exists)
    {
      return super._exists(uint(tokenId));
    }


    /*************** INTERNAL FUNCTIONS **************/


    /// @notice  Helper function for computing the token id of a RAYT for issuance.
    ///
    /// @dev     The hash/id is completely deterministic, but that shouldn't matter
    ///          since we have checks in place in other contracts to ensure
    ///          the integrity of a token id being entered (true owner/exists)
    ///
    /// @param   _salt - The variable we use to ensure token id's are unique from
    ///                  each other.
    ///
    /// TODO:     Stop passing in _salt as a parameter - waste of gas since its
    ///           already available in the global storage. Unless it's cheaper
    ///           to pass as an internal parameter over accessing global storage?
    function createIssuanceHash(uint _salt) internal view returns(bytes32)
    {
        bytes32 issuanceHash = keccak256(abi.encodePacked(address(this), _salt));
        return issuanceHash;
    }

}
