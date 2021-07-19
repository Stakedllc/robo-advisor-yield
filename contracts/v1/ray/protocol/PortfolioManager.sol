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
import "./impl/openzeppelin/ERC721/IERC721Receiver.sol";
import "./impl/openzeppelin/ERC721/IERC721.sol";
import "./impl/openzeppelin/ERC20/IERC20.sol";
import "./impl/openzeppelin/math/SafeMath.sol";

// internal dependencies
import "./interfaces/Approves.sol";
import "./interfaces/Upgradeable.sol";
import "./interfaces/IOpportunityManager.sol";
import "./interfaces/IPositionManager.sol";
import "./interfaces/IFeeModel.sol";
import "./interfaces/IOracle.sol";
import "./interfaces/INAVCalculator.sol";
import "./interfaces/IRAYToken.sol";
import "./interfaces/IStorageWrapper.sol";
import "./interfaces/IStorage.sol";



 /// @notice  PortfolioManager accepts users assets and mints RAY Tokens [RAYT].
 ///          The owner of the loans is the RAYT, not the user. This contract is
 ///          the user entry-point to the core RAY system.
 ///
 /// TODO:    Gas optimization in all contracts [once design is settled]
 ///
 /// Author:   Devan Purhar
 /// Version:  1.0.0

contract PortfolioManager is IERC721Receiver, Upgradeable, Approves {
    using SafeMath
    for uint256;


    /*************** STORAGE VARIABLE DECLARATIONS **************/

    /* TODO: Re-order declarations for gas optimization (not important for now) */


    // contracts used
    bytes32 internal constant RAY_TOKEN_CONTRACT = keccak256("RAYTokenContract");
    bytes32 internal constant FEE_MODEL_CONTRACT = keccak256("FeeModelContract");
    bytes32 internal constant ADMIN_CONTRACT = keccak256("AdminContract");
    bytes32 internal constant POSITION_MANAGER_CONTRACT = keccak256("PositionManagerContract");
    bytes32 internal constant STORAGE_WRAPPER_TWO_CONTRACT = keccak256("StorageWrapperTwoContract");
    bytes32 internal constant NAV_CALCULATOR_CONTRACT = keccak256("NAVCalculatorContract");
    bytes32 internal constant OPPORTUNITY_MANAGER_CONTRACT = keccak256("OpportunityManagerContract");
    bytes32 internal constant ORACLE_CONTRACT = keccak256("OracleContract");

    bytes32 internal constant name = keccak256("RAY");

    IStorage public _storage;
    bool public deprecated;


    /*************** EVENT DECLARATIONS **************/


    /// @notice  Logs the minting of a RAY token
    event LogMintRAYT(
        bytes32 indexed tokenId,
        bytes32 indexed portfolioId,
        address indexed beneficiary,
        uint value
    );


    /// @notice  Logs the minting of an Opportunity token
    event LogMintOpportunityToken(
      bytes32 tokenId,
      bytes32 indexed portfolioId
    );


    /// @notice  Logs the withdrawing from a RAY token
    event LogWithdrawFromRAYT(
      bytes32 indexed tokenId,
      uint value,
      uint tokenValue // used to calculate gross return off-chain
    );


    /// @notice  Logs the burning of a RAY token
    event LogBurnRAYT(
        bytes32 indexed tokenId,
        address indexed beneficiary,
        uint value,
        uint tokenValue // used to calculate gross return off-chain
    );


    /// @notice  Logs a deposit to a RAY token
    event LogDepositToRAYT(
        bytes32 indexed tokenId,
        uint value,
        uint tokenValue // used to calculate gross return off-chain
    );


    /*************** MODIFIER DECLARATIONS **************/


    /// @notice  Checks if the token id exists within the RAY token contract
    modifier existingRAYT(bytes32 tokenId)
    {
        require(
             IRAYToken(_storage.getContractAddress(RAY_TOKEN_CONTRACT)).tokenExists(tokenId),
            "#PortfolioMananger existingRAYT Modifier: This is not a valid RAYT"
        );

        _;
    }


    /// @notice  Checks the caller is our Oracle contract
    modifier onlyOracle()
    {

      require(
        _storage.getContractAddress(ORACLE_CONTRACT) == msg.sender,
        "#NCController onlyOracle Modifier: Only Oracle can call this"
      );

      _;

    }


    /// @notice  Checks the caller is our Admin contract
    modifier onlyAdmin()
    {

      require(
        _storage.getContractAddress(ADMIN_CONTRACT) == msg.sender,
        "#NCController onlyAdmin Modifier: Only Admin can call this"
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
            "#PortfolioMananger onlyGovernance Modifier: Only Governance can call this"
        );

        _;
    }


    /// @notice  Checks the opportunity entered is valid for the portfolio entered
    ///
    /// @param   portfolioId - The portfolio id
    /// @param   opportunityId - The opportunity id
    modifier isValidOpportunity(bytes32 portfolioId, bytes32 opportunityId)
    {

      require(_storage.isValidOpportunity(portfolioId, opportunityId),
      "#PortfolioMananger isValidOpportunity modifier: This is not a valid opportunity for this portfolio");

        _;
    }


    /// @notice  Checks the opportunity address entered is the correct one
    ///
    /// @param   opportunityId - The opportunity id
    /// @param   opportunity - The contract address of the opportunity
    ///
    /// TODO: Stop passing in, just access storage and grab from there
    modifier isCorrectAddress(bytes32 opportunityId, address opportunity)
    {

      require(_storage.getVerifier(opportunityId) == opportunity,
      "#PortfolioMananger isCorrectAddress modifier: This is not the correct address for this opportunity");

        _;
    }


    /// @notice  Use this on public functions only
    ///
    /// @param   portfolioId - The portfolio id
    modifier isValidPortfolio(bytes32 portfolioId)
    {

      require(_storage.getVerifier(portfolioId) != address(0),
      "#PortfolioMananger isValidPortfolio modifier: This is not a valid portfolio");

        _;
    }


    /// @notice  Checks if the contract has been set to deprecated
    modifier notDeprecated()
    {
        require(
             deprecated == false,
            "#PortfolioMananger notDeprecated Modifier: In deprecated mode - this contract has been deprecated"
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

      _storage = IStorage(__storage);

    }


    /// @notice  Fallback function to receive Ether
    ///
    /// @dev     Required to receive Ether from the OpportunityManager upon withdraws
    function() external payable {

    }



    /** --------------- USER ENTRYPOINTS ----------------- **/


    /// @notice  Allows users to send ETH or accepted ERC20's to this contract and
    ///          used as capital. In return the PM mints and gives them a RAYT which
    ///          represents their 'stake' in the investing pool. A RAYT maps to many shares.
    ///          The price of shares is determined by the NAV.
    ///
    /// @param   portfolioId - The portfolio id
    /// @param   beneficiary - The owner of the position, supports third-party buys
    /// @param   value - The amount to be invested, need so we can accept ERC20's
    ///
    /// @return   The unique token id of their RAY Token position
    function mint(
      bytes32 portfolioId,
      address beneficiary,
      uint value
    )
      external
      notDeprecated
      isValidPortfolio(portfolioId)
      payable
      returns(bytes32)
    {

        notPaused(portfolioId);
        verifyValue(portfolioId, msg.sender, value); // verify the amount they claim to have sent in
        uint pricePerShare = INAVCalculator(_storage.getContractAddress(NAV_CALCULATOR_CONTRACT)).getPortfolioPricePerShare(portfolioId);

        // create their RAY Token
        bytes32 tokenId = IPositionManager(_storage.getContractAddress(POSITION_MANAGER_CONTRACT)).createToken(
            portfolioId,
            _storage.getContractAddress(RAY_TOKEN_CONTRACT),
            beneficiary,
            value,
            pricePerShare
        );

        // record what portfolio this token belongs too, not in PositionManager since Opp tokens don't need that logic
        IStorageWrapper(_storage.getContractAddress(STORAGE_WRAPPER_TWO_CONTRACT)).setTokenKey(tokenId, portfolioId);

        // record what the rate was when they entered for tracking yield allowances
        // not in createToken() b/c Opp Tokens don't need this (unless we implement fees on them)
        uint cumulativeRate = IFeeModel(_storage.getContractAddress(FEE_MODEL_CONTRACT)).updateCumulativeRate(_storage.getPrincipalAddress(portfolioId));
        IStorageWrapper(_storage.getContractAddress(STORAGE_WRAPPER_TWO_CONTRACT)).setEntryRate(portfolioId, tokenId, cumulativeRate);
        // increase the available capital in this portfolio upon this investment
        IStorageWrapper(_storage.getContractAddress(STORAGE_WRAPPER_TWO_CONTRACT)).setAvailableCapital(portfolioId, _storage.getAvailableCapital(portfolioId) + value);

        emit LogMintRAYT(tokenId, portfolioId, beneficiary, value);

        return tokenId;

    }


    /// @notice  Adds capital to an existing RAYT, this doesn't restrict who adds,
    ///          addresses besides the owner can add value to the position.
    ///
    /// @dev     The value added must be in the same coin type as the position
    ///
    /// @param   tokenId - The unique id of the position
    /// @param   value - The amount of value they wish to add
    function deposit(
      bytes32 tokenId,
      uint value
    )
      external
      payable
      notDeprecated
      existingRAYT(tokenId)
    {

        bytes32 portfolioId = _storage.getTokenKey(tokenId);
        notPaused(portfolioId);
        verifyValue(portfolioId, msg.sender, value);

        // don't need the return value of this function (the tokens updated allowance), just need to carry the action out
        // since they're adding capital, they're going to a new "capital stage". Their
        // allowance will be calculated based on their new amount of capital from this point on.
        IFeeModel(_storage.getContractAddress(FEE_MODEL_CONTRACT)).updateAllowance(portfolioId, tokenId);

        uint tokenValueBeforeDeposit;
        uint pricePerShare;

        (tokenValueBeforeDeposit, pricePerShare) = INAVCalculator(_storage.getContractAddress(NAV_CALCULATOR_CONTRACT)).getTokenValue(portfolioId, tokenId);

        IPositionManager(_storage.getContractAddress(POSITION_MANAGER_CONTRACT)).increaseTokenCapital(
            portfolioId,
            tokenId,
            pricePerShare,
            value
        );

        IStorageWrapper(_storage.getContractAddress(STORAGE_WRAPPER_TWO_CONTRACT)).setAvailableCapital(portfolioId, _storage.getAvailableCapital(portfolioId) + value);

        emit LogDepositToRAYT(tokenId, value, tokenValueBeforeDeposit);

    }


    /// @notice   Part 1 of 3 to withdraw value from a RAY Position
    ///
    /// @dev      Caller must be the owner of the token or our GasFunder (Payer) contract
    ///
    /// @param    tokenId - The id of the position
    /// @param    valueToWithdraw - The value to withdraw
    /// @param    originalCaller - Unimportant unless Payer is the msg.sender, tells
    ///                            us who signed the original message.
    ///
    /// NOTE:     We no longer force a RAY token burn to unlock all value of the position
    function redeem(
      bytes32 tokenId,
      uint valueToWithdraw,
      address originalCaller
    )
      external
      notDeprecated
      existingRAYT(tokenId)
      returns(uint)
    {

        address addressToUse = INAVCalculator(_storage.getContractAddress(NAV_CALCULATOR_CONTRACT)).onlyTokenOwner(tokenId, originalCaller, msg.sender);

        uint totalValue;
        uint pricePerShare;

        bytes32 portfolioId = _storage.getTokenKey(tokenId);
        (totalValue, pricePerShare) = INAVCalculator(_storage.getContractAddress(NAV_CALCULATOR_CONTRACT)).getTokenValue(portfolioId, tokenId);

      uint valueAfterFee = redeem2(
          portfolioId,
          tokenId,
          pricePerShare,
          valueToWithdraw,
          totalValue,
          addressToUse
        );

      return valueAfterFee;

    }


     /// @notice  Implemented to receive ERC721 tokens. Main use case is for users to burn
     ///          and withdraw their RAYT and withdraw the underlying value. It clears
     ///          it's associated token data, burns the RAYT, and transfers the capital + yield
     ///
     /// @dev     Must return hash of the function signature for tx to be valid.
     ///
     /// @param   from - The last owner of the RAY before becoming us
     /// @param   tokenId - the unique id of the position
     ///
     /// TODO: find value of hash: bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))
     ////       and make it a constant.
    function onERC721Received
    (
        address /*operator*/,
        address from,
        uint256 tokenId,
        bytes /*data*/
    )
        public
        notDeprecated
        returns(bytes4)
    {

        bytes32 convertedTokenId = bytes32(tokenId);

        // optimization: should create local var to store the RAYT Contract Address rather then calling for it twice or more times
        if (
          (IRAYToken(_storage.getContractAddress(RAY_TOKEN_CONTRACT)).tokenExists(convertedTokenId)) &&
          (msg.sender == _storage.getContractAddress(RAY_TOKEN_CONTRACT))
        ) {

            bytes32 portfolioId = _storage.getTokenKey(convertedTokenId);

            uint totalValue;
            uint pricePerShare;
            uint valueAfterFee;
            (totalValue, pricePerShare) = INAVCalculator(_storage.getContractAddress(NAV_CALCULATOR_CONTRACT)).getTokenValue(portfolioId, convertedTokenId);

            // we allow ray tokens with zero value to be sent in still simply to burn
            if (totalValue > 0) {

              IOracle(_storage.getContractAddress(ORACLE_CONTRACT)).withdrawFromProtocols(portfolioId, totalValue, totalValue);

              valueAfterFee = IFeeModel(_storage.getContractAddress(FEE_MODEL_CONTRACT)).takeFee(portfolioId, convertedTokenId, totalValue, totalValue);

              IPositionManager(_storage.getContractAddress(POSITION_MANAGER_CONTRACT)).updateTokenUponWithdrawal(
                  portfolioId,
                  convertedTokenId,
                  totalValue,
                  pricePerShare,
                  _storage.getTokenShares(portfolioId, convertedTokenId),
                  INAVCalculator(_storage.getContractAddress(NAV_CALCULATOR_CONTRACT)).getPortfolioUnrealizedYield(portfolioId)
              );

            }

            // deletes entire values on the token (shares, capital, owner, existence, etc.)
            IStorageWrapper(_storage.getContractAddress(STORAGE_WRAPPER_TWO_CONTRACT)).deleteTokenValues(portfolioId, convertedTokenId);

            IRAYToken(_storage.getContractAddress(RAY_TOKEN_CONTRACT)).burn(tokenId);

            emit LogBurnRAYT(convertedTokenId, from, valueAfterFee, totalValue);

           // send them the assets, this could be 0 if the totalvalue was zero to begin with
           // could put this transfer in the bottom of if block for the totalvalue check since it would still be safe
           // against re-entrancy since we're using transfer()
            _transferFunds(portfolioId, from, valueAfterFee);

        }

        return bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
    }


    /** ----------------- ONLY ORACLE MUTATORS ----------------- **/


    /// @notice  Entrypoint of the Oracle to tell us where/how to lend
    ///
    /// @dev  Could pass in sha3 id and use _storage to find the appropriate contract address
    ///       but that is an extra external call when we can just do it free beforehand
    ///
    /// @param  portfolioId - The portfolio id we're lending for
    /// @param  opportunityId - The opportunity id we're lending too
    /// @param  opportunity - The contract address of our Opportunity contract
    /// @param  value - The amount to lend in-kind
    /// @param  subtract - Flag to let us know if we wish to subtract value lent
    ///                 from the available capital.
    function lend(
      bytes32 portfolioId,
      bytes32 opportunityId,
      address opportunity,
      uint value,
      bool subtract
    )
      external
      onlyOracle
      isValidPortfolio(portfolioId)
      // notDeprecated --> called in _lend
    {

        if (subtract) {

          // we don't want to call this on rebalances else we'd have to add capital as we withdrew it and
          // then when withdrawing to send to a user we'd have to subtract it right back off == waste of gas
          // this can't underflow, Oracle function that calls this has a check
          IStorageWrapper(_storage.getContractAddress(STORAGE_WRAPPER_TWO_CONTRACT)).setAvailableCapital(portfolioId, _storage.getAvailableCapital(portfolioId) - value);

        }

        _lend(portfolioId, opportunityId, opportunity, value);
    }


    /// @notice  Entrypoint of the Oracle to tell us where/how to withdraw
    ///
    /// @dev  Could pass in sha3 id and use _storage to find the appropriate contract address
    ///       but that is an extra external call when we can just do it free beforehand
    ///
    /// @param  portfolioId - The portfolio id we're withdrawing for
    /// @param  opportunityId - The opportunity id we're withdrawing from
    /// @param  opportunity - The contract address of our Opportunity contract
    /// @param  value - The amount to withdraw in-kind
    /// @param  add - Flag to let us know if we wish to add value withdrawn
    ///                 into the available capital.
    function withdraw(
      bytes32 portfolioId,
      bytes32 opportunityId,
      address opportunity,
      uint value,
      bool add
    )
      external
      onlyOracle
      isValidPortfolio(portfolioId)
      // notDeprecated --> called in _withdraw
    { // called by oracle to rebalance, withdraw during upgrade, or withdraw-From-Protocols

        // if we're paused, and the oracle is the one who called withdraw(), we want to re-add the withdrawn funds to availbale capital
        // we're probably upgrading the opportunity. We don't want to re-add to available capital if fee model is the sender b/c that
        // means a user is trying to withdraw from the RAY token (meaning the value flows out instead of staying around and being 'available capital')
        if (add) {

          IStorageWrapper(_storage.getContractAddress(STORAGE_WRAPPER_TWO_CONTRACT)).setAvailableCapital(portfolioId, _storage.getAvailableCapital(portfolioId) + value); // if we're paused we're not

        }

        _withdraw(portfolioId, opportunityId, opportunity, value);

    }


    /** ----------------- ONLY ADMIN MUTATORS ----------------- **/


    /// @notice  Public wrapper so we can call via our Admin contract
    ///
    /// @dev   If this is deprecated, should be no value, therefore this function will revert anyway, so we don't ned the deprecation flag
    ///        since it won't help us debug the error in prod. since error msgs don't show up
    function transferFunds(
      bytes32 portfolioId,
      address beneficiary,
      uint value
    )
      external
      onlyAdmin
    {

      _transferFunds(portfolioId, beneficiary, value);

    }


    /// @notice  Approve function for ERC20's
    ///
    /// @dev     Need to approve the OpportunityManager contract
    ///
    /// @param   token - Contract address of the token
    /// @param   beneficiary - The OpportunityManager contract for now
    function approve(
      address token,
      address beneficiary,
      uint amount
    )
      external
      onlyAdmin
    {

      require(
        IERC20(token).approve(beneficiary, amount),
        "#PortfolioMananger approve: Approval of ERC20 Token failed"
      );

    }


    /// @notice  Approval for ERC721's
    ///
    /// @dev     Used by Admin so it can deprecate this contract, it transfers
    ///          all the opporunity tokens to a new contract.
    ///
    /// @param   token - The contract address of the token
    function setApprovalForAll(
      address token,
      address to,
      bool approved
    )
      external
      onlyAdmin
    {

      IERC721(token).setApprovalForAll(to, approved);

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


    /// @notice  Direct OpportunityManager to lend capital
    ///
    /// @param  portfolioId - The portfolio id we're lending for
    /// @param  opportunityId - The opportunity id we're lending too
    /// @param  opportunity - The contract address of our Opportunity contract
    /// @param  value - The amount to lend in-kind
    function _lend(
      bytes32 portfolioId,
      bytes32 opportunityId,
      address opportunity,
      uint value
    )
      internal
      notDeprecated
      isValidOpportunity(portfolioId, opportunityId)
      isCorrectAddress(opportunityId, opportunity)
    {

      notPaused(portfolioId);

      bytes32 tokenId = _storage.getOpportunityToken(portfolioId, opportunityId);
      address principalAddress = _storage.getPrincipalAddress(portfolioId);
      bool isERC20;
      uint payableValue;
      (isERC20, payableValue) =  INAVCalculator(_storage.getContractAddress(NAV_CALCULATOR_CONTRACT)).calculatePayableAmount(principalAddress, value);

      if (tokenId == bytes32(0)) { // if this contract/portfolio don't have a position yet, buy one and lend

          tokenId = IOpportunityManager(_storage.getContractAddress(OPPORTUNITY_MANAGER_CONTRACT)).buyPosition.value(payableValue)(
            opportunityId,
            address(this),
            opportunity,
            principalAddress,
            value,
            isERC20
          );

          // we'll only have one opportunity token per opporutnity per portfolio
          IStorageWrapper(_storage.getContractAddress(STORAGE_WRAPPER_TWO_CONTRACT)).setOpportunityToken(portfolioId, opportunityId, tokenId);

          emit LogMintOpportunityToken(tokenId, portfolioId);

      } else { // else add capital to our existing portfolio's position

          IOpportunityManager(_storage.getContractAddress(OPPORTUNITY_MANAGER_CONTRACT)).increasePosition.value(payableValue)(
            opportunityId,
            tokenId,
            opportunity,
            principalAddress,
            value,
            isERC20
          );

      }

    }


    /// @notice  Direct OpportunityManager to withdraw funds
    ///
    /// @param  portfolioId - The portfolio id we're withdrawing for
    /// @param  opportunityId - The opportunity id we're withdrawing from
    /// @param  opportunity - The contract address of our Opportunity contract
    /// @param  value - The amount to withdraw in-kind
    function _withdraw(
      bytes32 portfolioId,
      bytes32 opportunityId,
      address opportunity,
      uint value
    )
      internal
      notDeprecated // need to block this even though nobody should have value left in the contract if it's deprecated, since the logic could be wrong
      isValidOpportunity(portfolioId, opportunityId)
      isCorrectAddress(opportunityId, opportunity)
    {

        uint yield = INAVCalculator(_storage.getContractAddress(NAV_CALCULATOR_CONTRACT)).getOpportunityYield(portfolioId, opportunityId, value);

        bytes32 tokenId = _storage.getOpportunityToken(portfolioId, opportunityId);
        address principalAddress = _storage.getPrincipalAddress(portfolioId);

        IOpportunityManager(_storage.getContractAddress(OPPORTUNITY_MANAGER_CONTRACT)).withdrawPosition(
          opportunityId,
          tokenId,
          opportunity,
          principalAddress,
          value,
          _storage.getIsERC20(principalAddress)
         );

        if (yield > 0) {

          INAVCalculator(_storage.getContractAddress(NAV_CALCULATOR_CONTRACT)).updateYield(portfolioId, yield);

        }

    }


    /// @notice  Part 2 of 3 to withdraw a tokens value
    ///
    /// @param   portfolioId - The portfolio id of the token
    /// @param   tokenId - The unique token we're withdrawing from
    /// @param   pricePerShare - The current price per share we're using
    /// @param   valueToWithdraw - THe value being withdrawn in-kind
    /// @param   totalValue - The total value of the token
    /// @param   addressToUse - Added to support us paying for user transactions
    function redeem2(
      bytes32 portfolioId,
      bytes32 tokenId,
      uint pricePerShare,
      uint valueToWithdraw,
      uint totalValue,
      address addressToUse
    )
      internal
      returns(uint)
    {

      address beneficiary = IPositionManager(_storage.getContractAddress(POSITION_MANAGER_CONTRACT)).verifyWithdrawer(
          portfolioId,
          tokenId,
          _storage.getContractAddress(RAY_TOKEN_CONTRACT),
          addressToUse, // person who called/signed to call this function
          pricePerShare,
          valueToWithdraw,
          totalValue
      );

      valueToWithdraw += IOracle(_storage.getContractAddress(ORACLE_CONTRACT)).withdrawFromProtocols(portfolioId, valueToWithdraw, totalValue);

      uint valueAfterFee = IFeeModel(_storage.getContractAddress(FEE_MODEL_CONTRACT)).takeFee(portfolioId, tokenId, valueToWithdraw, totalValue);

      redeem3(portfolioId, tokenId, valueToWithdraw, pricePerShare);

      emit LogWithdrawFromRAYT(tokenId, valueAfterFee, totalValue);

      _transferFunds(portfolioId, beneficiary, valueAfterFee);

      return valueAfterFee;

    }


    /// @notice  Part 3 of 3 for withdrawing from a position, updates the tokens storage
    ///          such as the shares, capital, etc.
    ///
    /// @param  portfolioId - The portfolio id we're withdrawing from
    /// @param  tokenId - The token we're withdrawing from
    /// @param  valueToWithdraw - The value being withdrawn
    /// @param  pricePerShare - The price per share we're using to calculate value
    function redeem3(
      bytes32 portfolioId,
      bytes32 tokenId,
      uint valueToWithdraw,
      uint pricePerShare
    )
      internal
    {

      IPositionManager(_storage.getContractAddress(POSITION_MANAGER_CONTRACT)).updateTokenUponWithdrawal(
          portfolioId,
          tokenId,
          valueToWithdraw,
          pricePerShare,
          _storage.getTokenShares(portfolioId, tokenId),
          INAVCalculator(_storage.getContractAddress(NAV_CALCULATOR_CONTRACT)).getPortfolioUnrealizedYield(portfolioId)
      );

    }


    /// @notice  Used to transfer ETH or ERC20's
    ///
    /// @param   portfolioId - The portfolio id, used to get the coin associated
    /// @param   beneficiary - The address to send funds to - is untrusted
    /// @param   value - The value to send in-kind
    function _transferFunds(
      bytes32 portfolioId,
      address beneficiary,
      uint value
    )
      internal
    {

      address principalAddress = _storage.getPrincipalAddress(portfolioId);

      if (_storage.getIsERC20(principalAddress)) {

        require(
          IERC20(principalAddress).transfer(beneficiary, value),
          "#PortfolioMananger _transferFunds(): Transfer of ERC20 Token failed"
        );

      } else {

        beneficiary.transfer(value);

      }

    }


    /// @notice  Verify the amount the sender claims to give to the system is true
    ///
    /// @dev     Used for ETH and ERC20's
    ///
    /// @param   portfolioId - The portfolio id, used to get the coin associated
    /// @param   funder - The payer of the transaction
    /// @param   inputValue - The value the user said they're contributing by parameter
    function verifyValue(
      bytes32 portfolioId,
      address funder,
      uint inputValue
    )
      internal
    {

      address principalAddress = _storage.getPrincipalAddress(portfolioId);

      if (_storage.getIsERC20(principalAddress)) {

        require(
          IERC20(principalAddress).transferFrom(funder, address(this), inputValue),
          "#PortfolioMananger verifyValue: TransferFrom of ERC20 Token failed"
        );

      } else {

        require(
          inputValue == msg.value,
          "#PortfolioMananger verifyValue(): ETH value sent does not match input value");

      }

    }


    /// @notice  Checks if the portfolio or this Opportunity has been paused.
    ///
    /// @dev     Withdrawals are allowed on pauses, lending or accepting value isn't
    function notPaused(bytes32 portfolioId) internal view {

      require(
             _storage.getPausedMode(name) == false &&
             _storage.getPausedMode(portfolioId) == false,
             "#PortfolioMananger notPaused: In withdraw mode - this function has been paused"
         );

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
          IERC20(principalToken).transfer(_storage.getGovernanceWallet(), value),
         "PortfolioManager fallbackClaim(): ERC20 Transfer failed"
       );

      } else {

        _storage.getGovernanceWallet().transfer(value);

      }

    }

}
