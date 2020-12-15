//SPDX-License-Identifier: Unlicense
pragma solidity 0.5.17;

import "./interfaces/IOpportunity.sol";
import "./libraries/Initializable.sol";
import "./interfaces/IStorage.sol";


// Remove hardhat/console.sol for production
import "hardhat/console.sol";

import { IMasset } from "@mstable/protocol/contracts/interfaces/IMasset.sol";
import { ISavingsContract } from "@mstable/protocol/contracts/interfaces/ISavingsContract.sol";
// import IERC20 from ''
contract MStable is IOpportunity, Initializable {

  bytes32 internal constant ADMIN_CONTRACT = keccak256("AdminContract");
  bytes32 internal constant OPPORTUNITY_MANAGER_CONTRACT = keccak256("RAYv3Contract");
  
  IStorage public rayStorage;

  // map principal tokens to contracts to call
  //  -> not in storage since this unique to MyOpportunity
  mapping(address => address) public markets;


  ISavingsContract public savingsContract;
  // NOTE: Mapping can be changed to a struct or any other data structure needed
  // Ex:
  // 
  // struct MyOpportunityMarket {
  //   address otherAddress;
  //   uint32 usefulValue;
  //   int8 decimals;
  // }
  // mapping(address => MyOpportunityMarket) public markets;

    /*************** MODIFIER DECLARATIONS **************/


  /// @notice  Checks the caller is our Admin contract
  modifier onlyAdmin() {
      require(
          msg.sender == rayStorage.getContractAddress(ADMIN_CONTRACT),
          "#MyOpportunity onlyAdmin Modifier: Only Admin can call this"
      );

      _;
  }


  /// @notice  Checks the caller is our OpportunityManager contract
  modifier onlyOpportunityManager() {
      require(
          msg.sender == rayStorage.getContractAddress(OPPORTUNITY_MANAGER_CONTRACT),
          "#MyOpportunity onlyOpportunityManager Modifier: Only OpportunityManager can call this"
      );

      _;
  }

  /// @notice  Initialize Opportunity
  ///
  /// @param   storage_contract - address of the storage contract
  /// @param   principalToken - address array of the principal token
  /// @param   otherToken - address array of the other token
  function initialize(
    address storage_contract, 
    address[] memory principalToken,  // Optional
    address[] memory otherToken,
    address _savingsContract,
    //address _opportunityManager,      // Optional
    // <add any parameters neeeded>
  ) public initializer {
    rayStorage = IStorage(storage_contract);
    savingContracts = ISavingsContract(_savingContracts)
    

    _addPrincipalTokens(principalToken, otherToken);

  }

  /// @notice  Fallback function to receive Ether
  ///
  /// @dev     Required to receive Ether from MyOpportunity upon withdrawal
  function() external payable {  }

  /// @notice  Supply assets to the underlying Opportunity
  ///
  /// @param   token - address of the token to supply
  ///                           case of ETH
  /// @param   amount - amount in the smallest unit of the token to supply
  /// @param   isERC20 - boolean if the token follows the ERC20 standard
  function supply(address token, uint amount, bool isERC20) external onlyOpportunityManager payable {
   //  address compoundMarket = markets[principalToken];
        massetContract = markets[token]

      // mint MAsset
        IERC20(token).safeApprove(massetContract, uint256(-1));
        uint256 _amount = IMasset(massetContract).mint(token, amount);

      // deposit to savings

        IERC20(massetContract).safeApprove(savingsContract, uint256(-1));
        savingsContract.depositSavings(_amount);





      

  }


  /// @notice  Withdraw assets to the underlying Opportunity
  ///
  /// @param   token - address of the token to withdraw
  ///                           case of ETH
  /// @param   beneficiary - address to send the token too
  /// @param   amount - amount in the smallest unit of the token to supply
  /// @param   isERC20 - boolean if the token follows the ERC20 standard
  function withdraw(address token, address beneficiary, uint amount, bool isERC20) external onlyOpportunityManager {
         
         
         uint256 creditsToRedeem = helper.getSaveRedeemInput(save, amount);
        uint256 _bAssetQuantity = savingsContract.redeem(creditsToRedeem);
         
        uint256 value = IMasset(massetContract).redeem(_bAsset, _bAssetQuantity);
         
         
         // missing part where the opportunity manager transfer tokens to owner
         IERC20(token).transfer(beneficiary, value)
  
  }


  /// @notice  The amount supplied + yield generated in the underlyng Opporutnity
  ///
  /// @param   token - address of the token to get the balance of
  function getBalance(address token) external returns (uint){
    
  }


  /** ----------------- ONLY ADMIN MUTATORS ----------------- **/
  /// @notice  Add support for a coin
  ///
  /// @dev     This is configured in-contract since it's not common across Opportunities
  ///
  /// @param   principalTokens - The coin contract addresses
  /// @param   otherContracts - The other contracts that map to each coin
  function addPrincipalTokens(
    address[] memory principalTokens,
    address[] memory otherContracts
    // <add any parameters neeeded>
  )
    public // not using external b/c use memory to pass in array
    onlyAdmin
  {

    _addPrincipalTokens(principalTokens, otherContracts);

  }

  /*************** INTERNAL FUNCTIONS **************/

  /// @notice  Used to add coins support to this Opportunities configuration
  ///
  /// @dev     Internal version so we can call from the constructor and Admin Contract
  ///
  /// @param   principalTokens - The coin contract addresses
  /// @param   otherContracts - The other contracts that map to each coin
  function _addPrincipalTokens(
    address[] memory principalTokens,
    address[] memory otherContracts
    // <add any parameters neeeded>
  )
    internal
  {

    for (uint i = 0; i < principalTokens.length; i++) {

      markets[principalTokens[i]] = otherContracts[i];

    }

  }
}
