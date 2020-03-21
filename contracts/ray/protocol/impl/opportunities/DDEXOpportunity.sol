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
pragma experimental ABIEncoderV2;

// external dependency
import "../../../external/ddex/Actions.sol";
import "../openzeppelin/ERC20/ERC20.sol";

// internal dependency
import "../../interfaces/Opportunity.sol";
import "../../interfaces/MarketByContract.sol";

import "../Storage.sol";

/// @notice  Communicating Proxy to the DDEX Protocol
///
/// @dev     Follows the standard 'Opportunity' interface
///
/// Author:  Radar Bear
/// Version: 1.0.0

contract DDEXOpportunity is Opportunity, MarketByContract {
    /*************** STORAGE VARIABLE DECLARATIONS **************/

    // contracts used, this is how to dynamically reference RAY contracts from RAY Storage
    bytes32 internal constant ADMIN_CONTRACT = keccak256("AdminContract");
    bytes32 internal constant OPPORTUNITY_MANAGER_CONTRACT = keccak256(
        "OpportunityManagerContract"
    );

    address _DDEX;
    Storage public _storage;
    mapping(address => address) public tokenIdentifier;

    /*************** EVENT DECLARATIONS **************/

    /*************** MODIFIER DECLARATIONS **************/

    /// @notice  Checks the caller is our Governance Wallet
    ///
    /// @dev     To be removed once fallbacks are
    modifier onlyGovernance() {
        require(
            msg.sender == _storage.getGovernanceWallet(),
            "#DDEXImpl onlyGovernance Modifier: Only Governance can call this"
        );

        _;
    }

    /// @notice  Checks the caller is our Admin contract
    modifier onlyAdmin() {
        require(
            msg.sender == _storage.getContractAddress(ADMIN_CONTRACT),
            "#DDEXImpl : Only Admin can call this"
        );

        _;
    }

    /// @notice  Checks the caller is our OpportunityManager contract
    modifier onlyOpportunityManager() {
        require(
            msg.sender ==
                _storage.getContractAddress(OPPORTUNITY_MANAGER_CONTRACT),
            "#DDEXImpl : Only OpportunityManager can call this"
        );

        _;
    }

    /////////////////////// FUNCTION DECLARATIONS BEGIN ///////////////////////

    /// @notice  Sets Storage instance and inits the coins supported by the Opp.
    ///
    /// @param   __storage - The Storage contracts address
    /// @param   __DDEXAddress - DDEX contracts address

    constructor(address __storage, address __DDEXAddress) public {
        _storage = Storage(__storage);
        _DDEX = __DDEXAddress;
    }

    /// @notice  Fallback function to receive Ether
    ///
    /// @dev     Required to receive Ether from DDEX upon withdrawals
    function() external payable {}

    /** --------------- OpportunityManager ENTRYPOINTS ----------------- **/

    /// @notice  The entrypoint for OpportunityManager to lend
    ///
    /// @param    principalToken - The coin address to lend
    /// @param    value - The amount to lend
    function supply(address principalToken, uint256 value, bool isERC20)
        external
        payable
        onlyOpportunityManager
    {
        address tokenAddress = tokenIdentifier[principalToken];
        uint256 sendEth;

        if (isERC20) {
            require(
                IERC20(principalToken).approve(_DDEX, value),
                "DDEXImpl supply(): APPROVE_ERC20_FAILED"
            );
            sendEth = 0;
        } else {
            require(
                msg.value == value,
                "DDEXImpl supply(): MSG_VALUE_NOT_MATCH"
            );
            sendEth = msg.value;
        }

        // build DDEX batch actions
        Action memory action;
        action.ActionType = ActionType.Supply;
        action.encodedParams = abi.encode(tokenAddress, uint256(value));
        Action[] memory actions = new Action[](1);
        actions[0] = action;

        // DDEX batch doesn't return anything and reverts on error
        IDDEX(_DDEX).batch.value(sendEth)(actions);
    }

    /// @notice  The entrypoint for OpportunityManager to withdraw
    ///
    /// @param    principalToken - The coin address to withdraw
    /// @param    beneficiary - The address to send funds too - always OpportunityManager for now
    /// @param    valueToWithdraw - The amount to withdraw
    function withdraw(
        address principalToken,
        address beneficiary,
        uint256 valueToWithdraw,
        bool isERC20
    ) external onlyOpportunityManager {
        address tokenAddress = tokenIdentifier[principalToken];

        require(
            getBalance(principalToken) <= valueToWithdraw,
            "DDEXImpl withdraw(): Balance not enough"
        );

        // build DDEX batch actions
        Action memory action;
        action.ActionType = ActionType.Unsupply;
        action.encodedParams = abi.encode(tokenAddress, uint256(value));
        Action[] memory actions = new Action[](1);
        actions[0] = action;

        IDDEX(_DDEX).batch(actions);

        if (isERC20) {
            require(
                IERC20(principalToken).transfer(beneficiary, valueToWithdraw),
                "DDEXImpl withdraw(): Transfer of ERC20 Token failed"
            );
        } else {
            beneficiary.transfer(valueToWithdraw);
        }

    }

    /// @notice  DDEX contract send tokens to suppliers directly when bankrupt. This is the entrypoint for OpportunityManager to withdraw tokens remaining in the opportunity contract
    ///
    /// @param    principalToken - The coin address to withdraw
    /// @param    beneficiary - The address to send funds too - always OpportunityManager for now
    /// @param    valueToWithdraw - The amount to withdraw
    function withdrawRemainingTokens(
        address principalToken,
        address beneficiary,
        uint256 valueToWithdraw,
        bool isERC20
    ) external onlyOpportunityManager {
        if (isERC20) {
            require(
                IERC20(principalToken).transfer(beneficiary, valueToWithdraw),
                "DDEXImpl withdrawRemainingTokens(): Transfer of ERC20 Token failed"
            );
        } else {
            beneficiary.transfer(valueToWithdraw);
        }

    }

    /** ----------------- ONLY ADMIN MUTATORS ----------------- **/

    /// @notice  Add support for a coin
    ///
    /// @dev     This is configured in-contract since it's not common across Opportunities
    ///
    /// @param   principalTokens - The coin contract addresses
    /// @param   DDEXTokenId - The token id on DDEX platform contracts
    /// DDEX use token address to identify erc20 tokens
    /// while 0x000000000000000000000000000000000000000E for Ether
    function addPrincipalTokens(
        address[] memory principalTokens,
        address[] memory DDEXTokenId // not using external b/c use memory to pass in array
    ) public onlyAdmin {
        for (uint256 i = 0; i < principalTokens.length; i++) {
            tokenIdentifier[principalTokens[i]] = DDEXTokenId[i];
        }
    }

    /** ----------------- VIEW ACCESSORS ----------------- **/

    /// @notice  Get the current balance we have in the Opp. (principal + interest generated)
    ///
    /// @param   principalToken - The coins address
    ///
    /// @return  The total balance in the smallest units of the coin
    function getBalance(address principalToken)
        external
        view
        returns (uint256)
    {
        address tokenAddress = tokenIdentifier[principalToken];
        return IDDEX(_DDEX).getAmountSupplied(tokenAddress, this);
    }

}
