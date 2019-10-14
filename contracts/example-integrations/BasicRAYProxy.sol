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
import "./ray/openzeppelin/ERC721/IERC721Receiver.sol";
import "./ray/openzeppelin/ERC20/IERC20.sol";

// internal dependencies
import "./ray/RAY.sol";
import "./ray/IRAYStorage.sol";


/// @notice  Example of integrating with RAY through a smart contract. This contract
///          acts as a basic proxy for your users. It takes ownership of
///          minted RAY tokens in a trust-less manner. It needs ownership to
///          withdraw on behalf of your users if you're routing their calls through
///          here.
///
///          RAY supports paying for user-transactions, which is what the code
///          that mentions 'Payer' or 'GasFunder' is referring too. This is a
///          separate smart contract - currently we haven't deployed it, but when
///          we do you may want to have the support already built-into your contract.
///
/// @dev     Quickly thrown together, so may contain bugs. Please test appropriately.
///
/// Author:  Devan Purhar

contract BasicRAYProxy is IERC721Receiver {


  /*************** VARIABLE DECLARATIONS **************/


  // RAY smart contracts used, these id's can be used to identify them dynamically
  bytes32 internal constant ADMIN_CONTRACT = keccak256("AdminContract");
  bytes32 internal constant PORTFOLIO_MANAGER_CONTRACT = keccak256("PortfolioManagerContract");
  bytes32 internal constant PAYER_CONTRACT = keccak256("PayerContract");
  bytes32 internal constant RAY_TOKEN_CONTRACT = keccak256("RAYTokenContract");
  bytes32 internal constant NAV_CALCULATOR_CONTRACT = keccak256("NAVCalculatorContract");

  bytes4 internal constant ERC721_RECEIVER_STANDARD = bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
  address internal constant NULL_ADDRESS = address(0);

  IRAYStorage public rayStorage;

  // map the 'true' owners of the RAY tokens owned by this contract
  mapping(bytes32 => address) rayTokens;


  /*************** MODIFIER DECLARATIONS **************/


  /// @dev  A modifier that verifies either the msg.sender == our Payer contract
  ///       and then the original caller is passed as a parameter (so check the original caller)
  ///       since we trust Payer. Else msg.sender must be the true owner of the token.
  ///
  ///       This functionality enables paying for users transactions when interacting
  ///       with RAY.
  ///
  ///       origCaller is the address that signed the transaction that went through Payer
  modifier onlyTokenOwner(bytes32 tokenId, address origCaller)
  {
      if (msg.sender == rayStorage.getContractAddress(PAYER_CONTRACT)) {

        require(rayTokens[tokenId] == origCaller,
                "#BasicRAYProxy onlyTokenOwner modifier: The original caller is not the owner of the token");

      } else {

        require(rayTokens[tokenId] == msg.sender,
                "#BasicRAYProxy onlyTokenOwner modifier: The caller is not the owner of the token");

      }

      _;
  }


  /////////////////////// FUNCTION DECLARATIONS BEGIN ///////////////////////

  /******************* PUBLIC FUNCTIONS *******************/


  /// @notice  Init contract by referencing the Eternal storage contract of RAY
  ///
  /// @param   _rayStorage - The address of the RAY storage contract
  constructor(
    address _rayStorage
  )
      public
  {

    rayStorage = IRAYStorage(_rayStorage);

  }


  /// @notice  Fallback function to receive Ether
  ///
  /// @dev     Required to receive Ether from PortfolioManager upon withdraws
  function() external payable {

  }


  /** --------------------- RAY ENTRYPOINTS --------------------- **/


  /// @notice  Allows users to deposit ETH or accepted ERC20's to this contract and
  ///          used as capital. In return they receive an ERC-721 'RAY' token.
  ///
  /// @param   portfolioId - The portfolio id
  /// @param   beneficiary - The address that will own the position
  /// @param   value - The amount to be deposited denominated in the smallest units
  ///                  in-kind. Ex. For USDC, to deposit 1 USDC, value = 1000000
  ///
  /// @return   The unique token id of the new RAY token position
  function mint(
    bytes32 portfolioId,
    address beneficiary,
    uint value
  )
    external
    payable
    returns(bytes32)
  {

    address rayContract = rayStorage.getContractAddress(PORTFOLIO_MANAGER_CONTRACT);
    uint payableValue = verifyValue(portfolioId, msg.sender, value, rayContract);

    // this contract will own the minted RAY
    bytes32 rayTokenId = RAY(rayContract).mint.value(payableValue)(portfolioId, address(this), value); // payable value could be 0

    // map RAY's to their true owners
    rayTokens[rayTokenId] = beneficiary;

    return rayTokenId;

  }


  /// @notice  Adds capital to an existing RAY token, this doesn't restrict who
  ///          adds. Addresses besides the owner can add value to the position.
  ///
  /// @dev     The value added must be in the same underlying asset as the position.
  ///
  /// @param   rayTokenId - The unique id of the RAY token
  /// @param   value - The amount to be deposited denominated in the smallest units
  ///                  in-kind. Ex. For USDC, to deposit 1 USDC, value = 1000000
  function deposit(bytes32 rayTokenId, uint value) external payable {

    bytes32 portfolioId = rayStorage.getTokenKey(rayTokenId);
    address rayContract = rayStorage.getContractAddress(PORTFOLIO_MANAGER_CONTRACT);

    uint payableValue = verifyValue(portfolioId, msg.sender, value, rayContract);

    RAY(rayContract).deposit.value(payableValue)(rayTokenId, value);

  }


  /// @notice   Withdraw value from a RAY token
  ///
  /// @dev      Caller must be the 'true' owner of the token or RAY's GasFunder (Payer) contract
  ///
  /// @param    rayTokenId - The id of the position
  /// @param    valueToWithdraw - The value to withdraw
  /// @param    originalCaller - Unimportant unless Payer is the msg.sender, tells
  ///                            us who signed the original message.
  function redeem(bytes32 rayTokenId, uint valueToWithdraw, address originalCaller) external onlyTokenOwner(rayTokenId, originalCaller) {

    bytes32 portfolioId = rayStorage.getTokenKey(rayTokenId);
    address rayContract = rayStorage.getContractAddress(PORTFOLIO_MANAGER_CONTRACT);

    uint valueAfterFee = RAY(rayContract).redeem(rayTokenId, valueToWithdraw, originalCaller);

    address beneficiary = rayTokens[rayTokenId];
    transferFunds(portfolioId, beneficiary, valueAfterFee);

  }


  /// @notice  Gets a RAY tokens current value
  ///
  /// @param    rayTokenId - The unique token id of the RAY
  ///
  /// @return   Value of the token
  function getTokenValue(bytes32 rayTokenId) external view returns (uint) {

    uint tokenValue;
    uint pricePerShare;

    bytes32 portfolioId = rayStorage.getTokenKey(rayTokenId);
    address rayContract = rayStorage.getContractAddress(PORTFOLIO_MANAGER_CONTRACT);

    (tokenValue, pricePerShare) = RAY(rayStorage.getContractAddress(NAV_CALCULATOR_CONTRACT)).getTokenValue(portfolioId, rayTokenId);

    return tokenValue;

  }


  /// @notice  Required to recieve RAY tokens when they're minted
  function onERC721Received
  (
      address /*operator*/,
      address /*from*/,
      uint256 /*tokenId*/,
      bytes /*data*/
  )
      public
      returns(bytes4)
  {
      return ERC721_RECEIVER_STANDARD;
  }


  /************************ INTERNAL FUNCTIONS **********************/


  /// @notice  Verifies the funds have been credited to this contract and then
  ///          returns the 'payable' value - the amount of ETH to be forwarded.
  ///
  /// @param   portfolioId - The portfolioId the RAY being minted or deposited is
  ///                        associated with
  /// @param   funder - The address funding the transaction
  /// @param   inputValue - The value input to the function parameter
  /// @param   rayContract - The address of the PortfolioManager
  ///
  /// @return  The 'payable' value to be forwarded to the PortfolioManager
  function verifyValue(
    bytes32 portfolioId,
    address funder,
    uint inputValue,
    address rayContract
  )
    internal
    returns(uint)
  {

    address principalAddress = rayStorage.getPrincipalAddress(portfolioId);

    if (rayStorage.getIsERC20(principalAddress)) {

      require(
        IERC20(principalAddress).transferFrom(funder, address(this), inputValue),
        "#BasicRAYProxy verifyValue(): Transfer of ERC20 Token failed"
      );

      // could one time max approve the ray contract (or everytime it upgrades and changes addresses)
      require(
        IERC20(principalAddress).approve(rayContract, inputValue),
        "#BasicRAYProxy verifyValue(): Approval of ERC20 Token failed"
      );

      return 0;

    } else {

      require(inputValue == msg.value, "#RAY verifyValue(): ETH value sent does not match input value");
      return inputValue;

    }

  }


  /// @notice  Used to transfer ETH or ERC20's
  ///
  /// @param   portfolioId - The portfolio id, used to get the coin associated
  /// @param   beneficiary - The address to send funds to - is untrusted
  /// @param   value - The value to send in-kind in smallest units
  function transferFunds(bytes32 portfolioId, address beneficiary, uint value) internal {

    address principalAddress = rayStorage.getPrincipalAddress(portfolioId);

    if (rayStorage.getIsERC20(principalAddress)) {

      require(
        IERC20(principalAddress).transfer(beneficiary, value),
        "#BasicRAYProxy transferFunds(): Transfer of ERC20 token failed"
    );

    } else {

      beneficiary.transfer(value);

    }

  }


}
