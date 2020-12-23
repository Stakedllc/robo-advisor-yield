//SPDX-License-Identifier: Unlicense
pragma solidity 0.5.16;

import { IOpportunity } from  "./interfaces/IOpportunity.sol";
import { Initializable } from "./libraries/Initializable.sol";
import { IStorage } from "./interfaces/IStorage.sol";
// import { IERC20 } from'./interfaces/IERC20.sol';
import "./openzeppelin/SafeERC20.sol";
import "./openzeppelin/SafeMath.sol";
// Remove hardhat/console.sol for production
// import "hardhat/console.sol";

import { IMasset } from "./interfaces/IMasset.sol";
import { ISavingsContract } from "./interfaces/ISavingsContract.sol";
import { IMStableHelper } from './interfaces/IMStableHelper.sol';
// import IERC20 from ''
contract MStableOpportunity is IOpportunity, Initializable {
  using SafeERC20 for IERC20;
  using SafeMath for uint;

  bytes32 internal constant ADMIN_CONTRACT = keccak256("AdminContract");
  bytes32 internal constant OPPORTUNITY_MANAGER_CONTRACT = keccak256("RAYv3Contract");
  
  IStorage public rayStorage;

  // map principal tokens to contracts to call
  //  -> not in storage since this unique to MyOpportunity
  mapping(address => address) public markets;


  ISavingsContract public savingsContract;
  address public saveAddress;
  IMStableHelper public helper;
  address public mUSD;
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
    address _mStableHelper,
    address _mUSD
    //address _opportunityManager,      // Optional
    // <add any parameters neeeded>
  ) public initializer {
    rayStorage = IStorage(storage_contract);
    savingsContract = ISavingsContract(_savingsContract);
    helper = IMStableHelper(_mStableHelper);
    saveAddress = _savingsContract;
    mUSD = _mUSD;

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
 
 

   uint256 public _amount;   
 
  function supply(address token, uint amount, bool isERC20) external payable {
   //  address compoundMarket = markets[principalToken];
       address massetContract = markets[token];

      // transfer asset to the opportunity contract

        IERC20(token).transferFrom(msg.sender,address(this),amount);

      // mint new mUSD to deposit into savings contract
        uint256 _amount = IMasset(massetContract).mint(token, amount);
          
      // deposit to savings
        savingsContract.depositSavings(_amount);


       


      

  }

  uint256 public value;
  uint256 public creditsToRedeem;

  /// @notice  Withdraw assets to the underlying Opportunity
  ///
  /// @param   token - address of the token to withdraw
  ///                           case of ETH
  /// @param   beneficiary - address to send the token too
  /// @param   amount - amount in the smallest unit of the token to supply
  /// @param   isERC20 - boolean if the token follows the ERC20 standard

  function withdraw(address token, address beneficiary, uint amount, bool isERC20) external {
        
         address massetContract = markets[token];
         
        // calculate credits
         uint256 creditsToRedeem = helper.getSaveRedeemInput(savingsContract, amount);
       
        // get back mUSD asset from savings contract
        uint256 _bAssetQuantity = savingsContract.redeem(creditsToRedeem);
        uint256 _bAssetQuantityNew = _bAssetQuantity.div(1e12);
       // redeem mUSD for USDC 
        IMasset(massetContract).redeemTo(token, _bAssetQuantityNew, beneficiary);
      
        
  
  }

// TO APPROVE OUT OF THE CONTRACT 
// we approve infinity both on token and massetContract, still need TBD when we approve
 function approveOnce(address token) external {
      
      address massetContract = markets[token];
      IERC20(token).safeApprove(massetContract, uint256(-1));
      IERC20(massetContract).safeApprove(saveAddress, uint256(-1));
    

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
