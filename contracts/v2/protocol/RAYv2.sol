/**

    The software and documentation available in this repository (the "Software") is
    protected by copyright law and accessible pursuant to the license set forth below.

    Copyright © 2020 Staked Securely, Inc. All rights reserved.

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

pragma solidity 0.5.11;


// external dependencies
import "./openzeppelin/contracts-ethereum-package/token/ERC20/IERC20.sol";
import "./openzeppelin/contracts-ethereum-package/math/SafeMath.sol";
import "./openzeppelin/contracts-ethereum-package/math/Math.sol";
import "./openzeppelin/contracts-ethereum-package/utils/ReentrancyGuard.sol";
import "./openzeppelin/contracts-ethereum-package/utils/SafeCast.sol";

// internal dependencies
import './interfaces/IRoboToken.sol';
import './interfaces/IOpportunity.sol';
import './interfaces/IOpportunityToken.sol';
import './interfaces/IOpportunityManager.sol';
import "./interfaces/IApproves.sol";
import './interfaces/IUpgradeable.sol';
import './interfaces/IStorage.sol';


/// @notice  Core contract of RAY v2 Protocol
///
/// Author:   Devan Purhar
/// Version:  2.0.0
contract RAYv2 is ReentrancyGuard, IUpgradeable, IApproves {
  using SafeMath for uint256;
  using SafeCast for uint256;
  using Math for uint256;


  /*************** STORAGE VARIABLE DECLARATIONS **************/


  // contracts used
  bytes32 internal constant ADMIN_CONTRACT = keccak256("AdminContract");
  bytes32 internal constant ADMIN_TWO_CONTRACT = keccak256("AdminTwoContract");
  bytes32 internal constant OPPORTUNITY_MANAGER_CONTRACT = keccak256("OpportunityManagerContract");
  bytes32 internal constant POSITION_MANAGER_CONTRACT = keccak256("PositionManagerContract");
  bytes32 internal constant OPPORTUNITY_TOKEN_CONTRACT = keccak256("OpportunityTokenContract");

  bytes32 internal constant NULL_BYTES = bytes32(0);
  bytes32 internal constant NAME = keccak256("RAYv2");
  uint internal constant ON_CHAIN_PRECISION = 1e18;
  uint internal constant CEILING = 10;
  uint internal constant BURN_PERIOD = 2;
  uint internal constant ETH_STANDARD = 0;

  enum ExchangeRates { MINT, BURN, CURRENT }

  address public rayStorage;
  bool public deprecated;

  struct OpportunityNAVInfo {
    uint128 cachedMintNav;
    uint128 timeMintLastUpdated;
    uint128 cachedBurnNav;
    uint128 timeBurnLastUpdated;
    uint128 cachedBalance;
  }

  mapping (bytes32 => OpportunityNAVInfo) public opportunityNAVInfo;

  struct RoboToken {
    bytes32 portfolioId;
    bytes32[] opportunities;
    mapping (bytes32 => bytes32) opportunityTokens;
    mapping (bytes32 => uint) opportunityExposureAllowed;
  }

  mapping (address => RoboToken) public roboTokens;
  mapping (address => bool) internal roboTokenStatus;

  struct Asset {
    uint raised;
    uint coinStandard;
  }

  mapping (address => Asset) public assets;

  uint internal periodLength;


  /*************** EVENT DECLARATIONS **************/


  /// @notice  Used to calculate the gross return off-chain by providing the capital
  ///          deposited upon a mint txn.
  ///
  /// @param  roboToken - The RoboToken being minted
  /// @param  minter - The sender of the mint transaction
  /// @param  amountDeposited - The amount of underlying deposited to the RoboToken
  event LogMintRoboTokens(
    address roboToken,
    address minter,
    uint amountDeposited // used to calculate the gross return off-chain
  );


  /// @notice  Used to calculate the gross return off-chain by providing the underlying
  ///          withdrawn and the total value of the tokens beforehand upon a burn txn.
  ///
  /// @param  roboToken - The RoboToken being burned
  /// @param  burner - The sender of the burn transaction
  /// @param  amountWithdrawn - The amount of underlying withdrawn from the RoboToken
  /// @param  totalUnderlying - The total amount of underlying before the burn
  event LogBurnRoboTokens(
    address roboToken,
    address burner,
    uint amountWithdrawn,
    uint totalUnderlying
  );


  /*************** MODIFIER DECLARATIONS **************/


  /// @notice  Checks if the contract has been set to deprecated
  modifier notDeprecated()
  {
      require(
           deprecated == false,
          "#RAYv2 notDeprecated Modifier: In deprecated mode - this contract has been deprecated"
      );

      _;
  }


  /// @notice  Checks the caller is one of our Admin contracts
  modifier onlyAdmin()
  {

    require(
      msg.sender == IStorage(rayStorage).getContractAddress(ADMIN_TWO_CONTRACT) ||
      msg.sender == IStorage(rayStorage).getContractAddress(ADMIN_CONTRACT),
      "#RAYv2 onlyAdmin Modifier: Only Admin can call this"
    );

    _;

  }


  /// @notice  Checks the caller is our PositionManager contract
  modifier onlyPositionManager()
  {

    require(
      msg.sender == IStorage(rayStorage).getContractAddress(POSITION_MANAGER_CONTRACT),
      "#RAYv2 onlyPositionManager Modifier: Only PositionManager can call this"
    );

    _;

  }


  /// @notice  Checks the caller is a RoboToken
  modifier onlyRoboTokens() {

    require(
         isRoboToken(msg.sender),
        "#RAYv2 onlyRoboTokens Modifier: Only RoboTokens can call this"
    );

    _;

  }


  /// @notice  Checks the caller is an approved [off-chain] Oracle
  modifier onlyOracles()
  {

    require(
      IStorage(rayStorage).getIsOracle(msg.sender),
      "#RAYv2 onlyOracles Modifier: Only Oracles can call this"
    );

    _;

  }


  /// @notice  Validates the amount entered is greater than zero
  modifier greaterThanZero(uint amount)
  {

    require(
      amount > 0,
      "#RAYv2 greaterThanZero Modifier: Amount must be greater than zero"
    );

    _;

  }


  /// @notice  Checks the opportunity entered is valid for the portfolio entered
  ///
  /// @param   portfolioId - The portfolio id
  /// @param   opportunityId - The opportunity id
  modifier isValidOpportunity(bytes32 portfolioId, bytes32 opportunityId)
  {

    require(
      IStorage(rayStorage).isValidOpportunity(portfolioId, opportunityId),
      "#RAYv2 isValidOpportunity modifier: This is not a valid opportunity for this portfolio"
    );

    _;

  }


  /////////////////////// FUNCTION DECLARATIONS BEGIN ///////////////////////


  /********************* PUBLIC FUNCTIONS **********************/


  /// @notice   Acts as the 'constructor', part of the proxy pattern.
  ///
  /// @param  _rayStorage - Address of the RAY storage contract
  /// @param  _periodLength - In seconds, ie. 3600 is 1 hour
  function initialize(address _rayStorage, uint _periodLength) public initializer {

      ReentrancyGuard.initialize();

      require(
        _rayStorage != address(0),
        "#RAYv2 initialize: RAY Storage cannot be equal to the null address."
      );

      rayStorage = _rayStorage;
      periodLength = _periodLength;

  }


  /// @notice  Fallback function to receive Ether
  ///
  /// @dev     Required to receive Ether from OM upon redeems and RoboTokens upon lend
  function() external payable {

  }


  /** ----------------- ONLY ADMIN MUTATORS ----------------- **/


  function setRoboToken(address roboTokenAddress, bool value) external onlyAdmin {

    roboTokenStatus[roboTokenAddress] = value;

  }


  function initRoboToken(address roboTokenAddress, bytes32 portfolioId) external onlyAdmin {

    roboTokens[roboTokenAddress].portfolioId = portfolioId;
    // This is an internal system contract call
    roboTokens[roboTokenAddress].opportunities = IStorage(rayStorage).getOpportunities(portfolioId);

    // this validates the entered portfolioId is valid, and that the portfolio is set-up correctly
    require(
      roboTokens[roboTokenAddress].opportunities.length > 0,
      "#RAYv2 initRoboToken: Opportunities length must be greater than zero."
    );

    // make it valid
    roboTokenStatus[roboTokenAddress] = true;

  }


  function setupAsset(address underlying, uint coinStandard, uint raised) external onlyAdmin {

    assets[underlying].coinStandard = coinStandard;
    assets[underlying].raised = raised;

  }


  function setPeriodLength(uint newPeriodLength) external onlyAdmin {

    periodLength = newPeriodLength;

  }


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
      "#RAYv2 approve: Approval of ERC20 Token failed"
    );

  }


  function setDeprecated(bool value) external onlyAdmin {

    deprecated = value;

  }


  /** ----------------- ONLY ORACLES MUTATORS ----------------- **/


  function updateNAVs(
    bytes32[] calldata portfolioIds
  )
    external
    notDeprecated
    onlyOracles
    nonReentrant
  {

    for (uint i = 0; i < portfolioIds.length; i++) {

      updateNAV(portfolioIds[i]);

    }

  }


  /// @notice  Entrypoint for the off-chain oracle to carry out rebalances or initial
  ///          lends.
  function rebalance(
    address roboTokenAddress,
    bytes32[] calldata wOpportunityIds,
    uint[] calldata wValues,
    bytes32[] calldata lOpportunityIds,
    uint[] calldata lValues
  )
    external
    notDeprecated
    onlyOracles
    nonReentrant
  {

    require(
         isRoboToken(roboTokenAddress),
        "#RAYv2 rebalance(): Must be a valid RoboToken"
    );

    bytes32 portfolioId = roboTokens[roboTokenAddress].portfolioId;
    address underlying = IRoboToken(roboTokenAddress).underlying();
    uint coinStandard = assets[underlying].coinStandard;

    require(
      notPaused(portfolioId),
      "#RAYv2 rebalance(): In withdraw mode - this function has been paused"
    );

    require(
      lOpportunityIds.length == lValues.length &&
      wOpportunityIds.length == wValues.length,
      "#RoboTokens rebalance(): Same-type arrays must be the same length"
    );

    _rebalance(
      roboTokenAddress,
      wOpportunityIds,
      wValues,
      lOpportunityIds,
      lValues,
      portfolioId,
      underlying,
      coinStandard
    );

  }


  /** ----------------- ONLY POSITION MANAGER MUTATORS ----------------- **/


  /// @notice  Restarts the cached NAV of an opportunity to its base price.
  function restartCachedNAV(bytes32 opportunityId) external notDeprecated onlyPositionManager {

    uint128 castDownPrice = SafeCast.toUint128(ON_CHAIN_PRECISION);
    uint128 castDownNow = SafeCast.toUint128(now);

    opportunityNAVInfo[opportunityId].cachedMintNav = castDownPrice;
    opportunityNAVInfo[opportunityId].cachedBurnNav = castDownPrice;

    opportunityNAVInfo[opportunityId].timeMintLastUpdated = castDownNow;
    opportunityNAVInfo[opportunityId].timeBurnLastUpdated = castDownNow;

  }


  /** ----------------- ONLY ROBOTOKEN MUTATORS ----------------- **/


  /// @notice    Gets the portfolio NAV of RoboToken, potentially updates internal
  ///            state if the cached NAV data is stale.
  function getPortfolioNAVType(
    address underlying,
    uint availableUnderlying,
    ExchangeRates rateType
  )
    external
    notDeprecated
    onlyRoboTokens
    nonReentrant
    returns (uint, uint)
  {

    bytes32[] memory opportunities = roboTokens[msg.sender].opportunities;
    uint raised = assets[underlying].raised;

    uint totalPortfolioBalance = getPortfolioTotalBalance(opportunities, underlying, msg.sender, raised, availableUnderlying, rateType);

    uint portfolioNav = calculatePortfolioNAV(totalPortfolioBalance, raised, msg.sender);

    return (portfolioNav, raised);

  }


  /// @notice    Calculates the tokens to mint for a deposit.
  function calculateTokensToMint(
    address underlying,
    address user,
    uint amountDeposited,
    uint availableUnderlying
  )
    external
    notDeprecated
    onlyRoboTokens
    nonReentrant
    greaterThanZero(amountDeposited)
    returns (uint)
  {

    require(
      notPaused(roboTokens[msg.sender].portfolioId),
      "#RAYv2 calculateTokensToMint(): In withdraw mode - this function has been paused"
    );

    bytes32[] memory opportunities = roboTokens[msg.sender].opportunities;
    uint raised = assets[underlying].raised;

    uint portfolioNav = getPortfolioMintNAV(opportunities, underlying, msg.sender, raised, availableUnderlying);

    uint tokensToMint = amountDeposited.mul(raised).div(portfolioNav);

    emit LogMintRoboTokens(msg.sender, user, amountDeposited);

    return tokensToMint;

  }


  /// @notice    Calculates the underlying to redeem for an amount of tokens, then
  ///            executes the withdrawals.
  function redeemRoboTokens(
    address underlying,
    uint redeemTokens,
    uint availableUnderlying,
    address user,
    uint userTotalTokens
  )
    external
    notDeprecated
    onlyRoboTokens
    nonReentrant
    greaterThanZero(redeemTokens)
    returns (uint)
  {

    require(
      userTotalTokens >= redeemTokens,
      "#RAYv2 redeemRoboTokens(): Not enough tokens owned to redeem this amount."
    );

    bytes32[] memory opportunities = roboTokens[msg.sender].opportunities;
    uint raised = assets[underlying].raised;
    uint coinStandard = assets[underlying].coinStandard;

    uint amountToRedeem = _redeemRoboTokens(opportunities, raised, coinStandard, underlying, redeemTokens, availableUnderlying, user, userTotalTokens);

    return amountToRedeem;

  }


  /// @notice    Calculates the tokens to redeem for an amount of underlying, then
  ///            executes the withdrawals.
  function redeemUnderlyingRoboTokens(
    address underlying,
    uint amountToRedeem,
    uint availableUnderlying,
    address user,
    uint userTotalTokens
  )
    external
    notDeprecated
    onlyRoboTokens
    nonReentrant
    greaterThanZero(amountToRedeem)
    returns (uint)
  {

    bytes32[] memory opportunities = roboTokens[msg.sender].opportunities;
    uint raised = assets[underlying].raised;
    uint coinStandard = assets[underlying].coinStandard;

    uint tokensToRedeem = _redeemUnderlyingRoboTokens(opportunities, raised, coinStandard, underlying, amountToRedeem, availableUnderlying, user, userTotalTokens);

    return tokensToRedeem;

  }


  /** ----------------- PERMISSIONLESS ACCESSORS ----------------- **/


  function getOpportunityToken(
    address roboTokenAddress,
    bytes32 opportunityId
  )
    external
    notDeprecated
    view
    returns (bytes32)
  {

    return roboTokens[roboTokenAddress].opportunityTokens[opportunityId];

  }


  function isRoboToken(address addressToCheck) public notDeprecated view returns (bool) {

    return roboTokenStatus[addressToCheck];

  }


  /********************* INTERNAL FUNCTIONS **********************/


  /** ----------------- INTERNAL MUTATORS ----------------- **/


  function _redeemRoboTokens(
    bytes32[] memory opportunities,
    uint raised,
    uint coinStandard,
    address underlying,
    uint redeemTokens,
    uint availableUnderlying,
    address user,
    uint userTotalTokens
  )
    internal
    returns (uint)
  {

    uint amountToRedeem;
    uint[] memory opportunitiesTokenValues = new uint[](opportunities.length);
    uint[] memory opportunitiesNavs = new uint[](opportunities.length);

    (amountToRedeem, opportunitiesTokenValues, opportunitiesNavs) = calculateUnderlyingToRedeem(opportunities, underlying, msg.sender, raised, redeemTokens, availableUnderlying, user, userTotalTokens);

    internalRedeem(opportunities, underlying, msg.sender, coinStandard, amountToRedeem, availableUnderlying, opportunitiesTokenValues, opportunitiesNavs);

    return amountToRedeem;

  }


  function _redeemUnderlyingRoboTokens(
    bytes32[] memory opportunities,
    uint raised,
    uint coinStandard,
    address underlying,
    uint amountToRedeem,
    uint availableUnderlying,
    address user,
    uint userTotalTokens
  )
    internal
    returns (uint)
  {

    uint tokensToRedeem;
    uint[] memory opportunitiesTokenValues = new uint[](opportunities.length);
    uint[] memory opportunitiesNavs = new uint[](opportunities.length);

    (tokensToRedeem, opportunitiesTokenValues, opportunitiesNavs) = calculateTokensToRedeem(opportunities, underlying, msg.sender, raised, amountToRedeem, availableUnderlying, user, userTotalTokens);

    internalRedeem(opportunities, underlying, msg.sender, coinStandard, amountToRedeem, availableUnderlying, opportunitiesTokenValues, opportunitiesNavs);

    return tokensToRedeem;

  }


  function calculateUnderlyingToRedeem(
    bytes32[] memory opportunities,
    address underlying,
    address roboTokenAddress,
    uint raised,
    uint redeemTokens,
    uint availableUnderlying,
    address user,
    uint userTotalTokens
  )
    internal
    returns (uint, uint[] memory, uint[] memory)
  {
    uint portfolioNav;
    uint[] memory opportunitiesTokenValues = new uint[](opportunities.length);
    uint[] memory opportunitiesNavs = new uint[](opportunities.length);

    (portfolioNav, opportunitiesTokenValues, opportunitiesNavs) = getPortfolioNAVWithMem(opportunities, underlying, roboTokenAddress, raised, availableUnderlying);

    uint amountToRedeem = portfolioNav.mul(redeemTokens).div(raised);

    emit LogBurnRoboTokens(msg.sender, user, amountToRedeem, portfolioNav.mul(userTotalTokens));

    return (amountToRedeem, opportunitiesTokenValues, opportunitiesNavs);

  }


  function calculateTokensToRedeem(
    bytes32[] memory opportunities,
    address underlying,
    address roboTokenAddress,
    uint raised,
    uint redeemAmount,
    uint availableUnderlying,
    address user,
    uint userTotalTokens
  )
    internal
    returns (uint, uint[] memory, uint[] memory)
  {
    uint portfolioNav;
    uint[] memory opportunitiesTokenValues = new uint[](opportunities.length);
    uint[] memory opportunitiesNavs = new uint[](opportunities.length);

    (portfolioNav, opportunitiesTokenValues, opportunitiesNavs) = getPortfolioNAVWithMem(opportunities, underlying, roboTokenAddress, raised, availableUnderlying);

    uint tokensRequiredToHave = redeemAmount.mul(raised).div(portfolioNav);

    require(
      tokensRequiredToHave > 0,
      "#RAYv2 calculateTokensToRedeem(): Must burn at least one token"
    );

    require(
      tokensRequiredToHave <= userTotalTokens,
      "#RAYv2 calculateTokensToRedeem(): Not enough tokens owned to redeem this amount"
    );

    uint tokensToRedeem = ceilOrMax(tokensRequiredToHave, CEILING, userTotalTokens);

    emit LogBurnRoboTokens(msg.sender, user, redeemAmount, portfolioNav.mul(userTotalTokens));

    return (tokensToRedeem, opportunitiesTokenValues, opportunitiesNavs);

  }


  function internalRedeem(
    bytes32[] memory opportunities,
    address underlying,
    address roboTokenAddress,
    uint coinStandard,
    uint amountToRedeem,
    uint availableUnderlying,
    uint[] memory opportunitiesTokenValues,
    uint[] memory opportunitiesNavs
  )
    internal
  {

    if (amountToRedeem <= availableUnderlying) {

      return;
    }

    uint leftToWithdraw = amountToRedeem.sub(availableUnderlying);

    bool isERC20 = convertCoinStandardToBool(coinStandard);

    internalRedeemTwo(leftToWithdraw, underlying, roboTokenAddress, isERC20, opportunities, opportunitiesTokenValues, opportunitiesNavs);

  }


  function internalRedeemTwo(
    uint valueToWithdraw,
    address underlying,
    address roboTokenAddress,
    bool isERC20,
    bytes32[] memory opportunities,
    uint[] memory opportunitiesTokenValues,
    uint[] memory opportunitiesNavs
  )
    internal
  {

    uint leftToWithdraw = valueToWithdraw;

    uint index = lookForSingleCoverage(leftToWithdraw, opportunitiesTokenValues);

    if (index == opportunitiesTokenValues.length) {
      index = 0;
    }

   for (uint i = index; i < opportunities.length; i++) {

       uint opportunityTokenValue = opportunitiesTokenValues[i];

       if (opportunityTokenValue <= 0) {

         continue;

       }

       address opportunity = IStorage(rayStorage).getVerifier(opportunities[i]);
       uint amountToRedeem;

       if (leftToWithdraw <= opportunityTokenValue) {

         amountToRedeem = leftToWithdraw;

       } else {

         amountToRedeem = opportunityTokenValue;

       }

       leftToWithdraw = leftToWithdraw.sub(amountToRedeem);

       executeWithdraw(
         opportunities[i],
         opportunity,
         underlying,
         roboTokenAddress,
         isERC20,
         amountToRedeem,
         opportunitiesNavs[i]
       );

       if (leftToWithdraw == 0) {

         break;

       }

     }

  }


  function executeWithdraw(
    bytes32 opportunityId,
    address opportunity,
    address underlying,
    address roboTokenAddress,
    bool isERC20,
    uint amountToRedeem,
    uint opportunityNav
  )
    internal
  {

    bytes32 opportunityTokenId = roboTokens[roboTokenAddress].opportunityTokens[opportunityId];

    IOpportunityManager(IStorage(rayStorage).getContractAddress(OPPORTUNITY_MANAGER_CONTRACT)).withdrawPositionWithMem(
      opportunityId,
      opportunityTokenId,
      opportunity,
      underlying,
      roboTokenAddress,
      amountToRedeem,
      opportunityNav,
      isERC20
     );

  }


  function _rebalance(
    address roboTokenAddress,
    bytes32[] memory wOpportunityIds,
    uint[] memory wValues,
    bytes32[] memory lOpportunityIds,
    uint[] memory lValues,
    bytes32 portfolioId,
    address underlying,
    uint coinStandard
  )
    internal
  {

    uint totalLent;
    uint totalWithdrawn;

    for (uint i = 0; i < lOpportunityIds.length; i++) {
      totalLent = totalLent.add(lValues[i]);
    }

    for (uint i = 0; i < wOpportunityIds.length; i++) {

      bytes32 opportunityTokenId = roboTokens[roboTokenAddress].opportunityTokens[wOpportunityIds[i]];
      totalWithdrawn = totalWithdrawn.add(wValues[i]);

      withdrawAction(portfolioId, wOpportunityIds[i], opportunityTokenId, underlying, coinStandard, wValues[i]);

    }

    require(
      totalLent >= totalWithdrawn,
      "#RoboToken rebalance(): Total withdrawn cannot be more than total lent"
    );

    if (totalLent > totalWithdrawn) {

      uint amountToTransfer = totalLent.sub(totalWithdrawn);

      IRoboToken(roboTokenAddress).transferFundsToCore(amountToTransfer);
    }

    for (uint i = 0; i < lOpportunityIds.length; i++) {

      lendAction(portfolioId, lOpportunityIds[i], roboTokenAddress, underlying, coinStandard, lValues[i]);

    }

  }


  function lendAction(
    bytes32 portfolioId,
    bytes32 opportunityId,
    address roboTokenAddress,
    address underlying,
    uint coinStandard,
    uint amountToLend
  )
    internal
    isValidOpportunity(portfolioId, opportunityId)
  {

    bytes32 opportunityTokenId = roboTokens[roboTokenAddress].opportunityTokens[opportunityId];

    bytes32 newOpportunityTokenId = lend(opportunityId, opportunityTokenId, underlying, coinStandard, amountToLend);

    if (opportunityTokenId == NULL_BYTES) {

       roboTokens[roboTokenAddress].opportunityTokens[opportunityId] = newOpportunityTokenId;

    }

  }


  function lend(
    bytes32 opportunityId,
    bytes32 opportunityTokenId,
    address underlying,
    uint coinStandard,
    uint value
  )
    internal
    returns (bytes32)
  {

    address opportunity = IStorage(rayStorage).getVerifier(opportunityId);
    uint payableValue;

    if (coinStandard == ETH_STANDARD) {
      payableValue = value;
    }

    bytes32 mutableOppTokenId = _lend(
      opportunityId,
      opportunityTokenId,
      underlying,
      opportunity,
      coinStandard,
      value,
      payableValue
    );

    return mutableOppTokenId;

  }


  function _lend(
    bytes32 opportunityId,
    bytes32 opportunityTokenId,
    address underlying,
    address opportunity,
    uint coinStandard,
    uint value,
    uint payableValue
  )
    internal
    returns (bytes32)
  {

    bool isERC20 = convertCoinStandardToBool(coinStandard);

    if (opportunityTokenId == bytes32(0)) {

        opportunityTokenId = IOpportunityManager(IStorage(rayStorage).getContractAddress(OPPORTUNITY_MANAGER_CONTRACT)).buyPosition.value(payableValue)(
          opportunityId,
          address(this),
          opportunity,
          underlying,
          value,
          isERC20
        );

    } else {

        IOpportunityManager(IStorage(rayStorage).getContractAddress(OPPORTUNITY_MANAGER_CONTRACT)).increasePosition.value(payableValue)(
          opportunityId,
          opportunityTokenId,
          opportunity,
          underlying,
          value,
          isERC20
        );

    }

    return opportunityTokenId;

  }


  function withdrawAction(
    bytes32 portfolioId,
    bytes32 opportunityId,
    bytes32 opportunityTokenId,
    address underlying,
    uint coinStandard,
    uint value
  )
    internal
    isValidOpportunity(portfolioId, opportunityId)
  {

      address opportunity = IStorage(rayStorage).getVerifier(opportunityId);

      bool isERC20 = convertCoinStandardToBool(coinStandard);

      IOpportunityManager(IStorage(rayStorage).getContractAddress(OPPORTUNITY_MANAGER_CONTRACT)).withdrawPosition(
        opportunityId,
        opportunityTokenId,
        opportunity,
        underlying,
        value,
        isERC20
       );

  }


  function getPortfolioTotalBalance(
    bytes32[] memory opportunities,
    address underlying,
    address roboTokenAddress,
    uint raised,
    uint availableUnderlying,
    ExchangeRates rateType
  )
    internal
    returns (uint)
  {

    uint totalPortfolioBalance = availableUnderlying;

    for (uint i = 0; i < opportunities.length; i++) {

      bytes32 opportunityId = opportunities[i];
      uint opportunityTokenValue;

      (opportunityTokenValue, ) = getOpportunityData(opportunityId, underlying, roboTokenAddress, raised, rateType);

      totalPortfolioBalance = totalPortfolioBalance.add(opportunityTokenValue);

    }

    return totalPortfolioBalance;

  }


  function getPortfolioTotalBalanceWithMem(
    bytes32[] memory opportunities,
    address underlying,
    address roboTokenAddress,
    uint raised,
    uint availableUnderlying,
    ExchangeRates rateType
  )
    internal
    returns (uint, uint[] memory, uint[] memory)
  {

    uint totalBalance = availableUnderlying;
    uint[] memory opportunitiesTokenValues = new uint[](opportunities.length);
    uint[] memory opportunitiesNavs = new uint[](opportunities.length);

    for (uint i = 0; i < opportunities.length; i++) {

      bytes32 opportunityId = opportunities[i];

      (opportunitiesTokenValues[i], opportunitiesNavs[i]) = getOpportunityData(opportunityId, underlying, roboTokenAddress, raised, rateType);

      totalBalance = totalBalance.add(opportunitiesTokenValues[i]);

    }

    return (totalBalance, opportunitiesTokenValues, opportunitiesNavs);

  }


  function getOpportunityData(
    bytes32 opportunityId,
    address underlying,
    address roboTokenAddress,
    uint raised,
    ExchangeRates rateType
  )
    internal
    returns (uint, uint)
  {

      bytes32 opportunityTokenId = roboTokens[roboTokenAddress].opportunityTokens[opportunityId];

      uint tokenValue;
      uint opportunityNav;

      if (opportunityTokenId != NULL_BYTES) {

        address opportunityToken = IStorage(rayStorage).getContractAddress(OPPORTUNITY_TOKEN_CONTRACT);

        require(
          IOpportunityToken(opportunityToken).tokenExists(opportunityTokenId),
          "#RAYv2 getOpportunityData(): Invalid opportunity token id"
        );

        uint opportunityTokenShares = IStorage(rayStorage).getTokenShares(opportunityId, opportunityTokenId);

        if (opportunityTokenShares == 0) {

          return (tokenValue, opportunityNav);

        }

        if (rateType == ExchangeRates.MINT) {

          opportunityNav = getOpportunityMintNAV(opportunityId, underlying, raised);

        } else if (rateType == ExchangeRates.BURN) {

          opportunityNav = getOpportunityBurnNAV(opportunityId, underlying, raised);

        } else {

          opportunityNav = getOpportunityCurrentNAV(opportunityId, underlying, raised);

        }

        tokenValue = opportunityNav.mul(opportunityTokenShares).div(raised);

      }

      return (tokenValue, opportunityNav);
  }


  function getOpportunityMintNAV(
    bytes32 opportunityId,
    address underlying,
    uint raised
  )
    internal
    returns (uint)
  {

      uint opportunityNav;

      uint timeSinceUpdated = now.sub(opportunityNAVInfo[opportunityId].timeMintLastUpdated); // = now - opportunityNAVInfo[opportunityId].timeMintLastUpdated

      if (timeSinceUpdated <= periodLength) {

        opportunityNav = opportunityNAVInfo[opportunityId].cachedMintNav;

      } else {

        opportunityNav = updateMintNAV(opportunityId, underlying, raised);
      }

      return (opportunityNav);
  }


  function getOpportunityBurnNAV(
    bytes32 opportunityId,
    address underlying,
    uint raised
  )
    internal
    returns (uint)
  {

      uint opportunityNav;

      uint timeSinceUpdated = now.sub(opportunityNAVInfo[opportunityId].timeBurnLastUpdated);

      if (timeSinceUpdated <= (periodLength.mul(BURN_PERIOD))) {

        opportunityNav = opportunityNAVInfo[opportunityId].cachedBurnNav;

      } else {

        opportunityNav = updateBurnNAV(opportunityId, underlying, raised);
      }

      return (opportunityNav);
  }


  function getOpportunityCurrentNAV(
    bytes32 opportunityId,
    address underlying,
    uint raised
  )
    internal
    returns (uint)
  {

    address opportunity = IStorage(rayStorage).getVerifier(opportunityId);

    uint opportunityBalance = IOpportunity(opportunity).getBalance(underlying);
    uint opportunityNav = calculateOpportunityNAV(opportunityId, opportunityBalance, raised);

    return opportunityNav;

  }


  function getPortfolioMintNAV(
    bytes32[] memory opportunities,
    address underlying,
    address roboTokenAddress,
    uint raised,
    uint availableUnderlying
  )
    internal
    returns (uint)
  {

    uint totalPortfolioBalance = getPortfolioTotalBalance(opportunities, underlying, roboTokenAddress, raised, availableUnderlying, ExchangeRates.MINT);

    return calculatePortfolioNAV(totalPortfolioBalance, raised, roboTokenAddress);

  }


  function getPortfolioNAVWithMem(
    bytes32[] memory opportunities,
    address underlying,
    address roboTokenAddress,
    uint raised,
    uint availableUnderlying
  )
    internal
    returns (uint, uint[] memory, uint[] memory)
  {

    uint totalPortfolioBalance;
    uint[] memory opportunitiesTokenValues = new uint[](opportunities.length);
    uint[] memory opportunitiesNavs = new uint[](opportunities.length);

    (totalPortfolioBalance, opportunitiesTokenValues, opportunitiesNavs) = getPortfolioTotalBalanceWithMem(opportunities, underlying, roboTokenAddress, raised, availableUnderlying, ExchangeRates.BURN);

    uint portfolioNav = calculatePortfolioNAV(totalPortfolioBalance, raised, roboTokenAddress);

    return (portfolioNav, opportunitiesTokenValues, opportunitiesNavs);

  }


  function updateNAV(bytes32 portfolioId) internal {

    bytes32[] memory opportunityIds = IStorage(rayStorage).getOpportunities(portfolioId);
    address underlying = IStorage(rayStorage).getPrincipalAddress(portfolioId);
    uint raised = IStorage(rayStorage).getRaised(underlying);

    for (uint i = 0; i < opportunityIds.length; i++) {

      _updateNAV(opportunityIds[i], underlying, raised);

    }

  }


  function _updateNAV(bytes32 opportunityId, address underlying, uint raised) internal {

    uint128 newBurnNav;
    uint128 newBurnTimestamp;

    uint opportunityNav = getOpportunityCurrentNAV(opportunityId, underlying, raised);

    uint timeSinceMintUpdated = now.sub(opportunityNAVInfo[opportunityId].timeMintLastUpdated);

    if (timeSinceMintUpdated <= (periodLength.mul(BURN_PERIOD)) && navIncreasedOrEqual(opportunityNav, opportunityNAVInfo[opportunityId].cachedMintNav)) {

      newBurnNav = opportunityNAVInfo[opportunityId].cachedMintNav;
      newBurnTimestamp = opportunityNAVInfo[opportunityId].timeMintLastUpdated;

    } else {

      newBurnNav = SafeCast.toUint128(opportunityNav);
      newBurnTimestamp = SafeCast.toUint128(now);

    }

    require(
      navIncreasedOrEqual(opportunityNav, opportunityNAVInfo[opportunityId].cachedBurnNav) ||
      IStorage(rayStorage).getPausedMode(NAME),
      "#RAYv2 _updateNAV(): Burn NAV decreased - in safe mode."
    );

    opportunityNAVInfo[opportunityId].cachedBurnNav = newBurnNav;
    opportunityNAVInfo[opportunityId].timeBurnLastUpdated = newBurnTimestamp;

    require(
      navIncreasedOrEqual(opportunityNav, opportunityNAVInfo[opportunityId].cachedMintNav) ||
      IStorage(rayStorage).getPausedMode(NAME),
      "#RAYv2 _updateNAV(): Mint NAV decreased - in safe mode."
    );

    opportunityNAVInfo[opportunityId].cachedMintNav = SafeCast.toUint128(opportunityNav);
    opportunityNAVInfo[opportunityId].timeMintLastUpdated = SafeCast.toUint128(now);

  }


  function updateMintNAV(bytes32 opportunityId, address underlying, uint raised) internal returns (uint) {

      uint opportunityNav = getOpportunityCurrentNAV(opportunityId, underlying, raised);

      require(
        navIncreasedOrEqual(opportunityNav, opportunityNAVInfo[opportunityId].cachedMintNav),
        "#RAYv2 updateMintNAV(): NAV decreased - in safe mode."
      );

      opportunityNAVInfo[opportunityId].cachedMintNav = SafeCast.toUint128(opportunityNav);
      opportunityNAVInfo[opportunityId].timeMintLastUpdated = SafeCast.toUint128(now);

      return opportunityNav;

  }


  function updateBurnNAV(bytes32 opportunityId, address underlying, uint raised) internal returns (uint) {

      uint128 newBurnNav;
      uint128 newBurnTimestamp;

      uint opportunityNav = getOpportunityCurrentNAV(opportunityId, underlying, raised);

      uint timeSinceMintUpdated = now.sub(opportunityNAVInfo[opportunityId].timeMintLastUpdated);

      if (timeSinceMintUpdated <= (periodLength.mul(BURN_PERIOD)) && navIncreasedOrEqual(opportunityNav, opportunityNAVInfo[opportunityId].cachedMintNav)) {

        newBurnNav = opportunityNAVInfo[opportunityId].cachedMintNav;
        newBurnTimestamp = opportunityNAVInfo[opportunityId].timeMintLastUpdated;

      } else {

        newBurnNav = SafeCast.toUint128(opportunityNav);
        newBurnTimestamp = SafeCast.toUint128(now);

      }

      opportunityNAVInfo[opportunityId].cachedBurnNav = newBurnNav;
      opportunityNAVInfo[opportunityId].timeBurnLastUpdated = newBurnTimestamp;

      return opportunityNAVInfo[opportunityId].cachedBurnNav;

  }


  /** ----------------- INTERNAL VIEW FUNCTIONS ----------------- **/


  function notPaused(bytes32 portfolioId) internal view returns (bool) {

    if (IStorage(rayStorage).getPausedMode(NAME) == false && IStorage(rayStorage).getPausedMode(portfolioId) == false) {
      return true;
    }

    return false;

  }


  function calculatePortfolioNAV(
    uint totalBalance,
    uint raised,
    address roboTokenAddress
  )
    internal
    view
    returns (uint)
  {

      uint nav;

      uint shareSupply = IERC20(roboTokenAddress).totalSupply();

      if (shareSupply > 0) {

        nav = totalBalance.mul(raised).div(shareSupply);

      } else {

        nav = ON_CHAIN_PRECISION;

      }

      require(nav != 0, "#RAYv2 calculatePortfolioNAV(): Zero is an invalid value for NAV.");

      return nav;

  }


  function calculateOpportunityNAV(
    bytes32 opportunityId,
    uint totalBalance,
    uint raised
  )
    internal
    view
    returns (uint)
  {

      uint nav;
      uint shareSupply = IStorage(rayStorage).getShareSupply(opportunityId);

      if (shareSupply > 0) {

        nav = totalBalance.mul(raised).div(shareSupply);

      } else {

        nav = ON_CHAIN_PRECISION;

      }

      require(nav != 0, "#RAYv2 calculateOpportunityNAV(): Zero is an invalid value for NAV.");

      return nav;

  }


  /** ----------------- INTERNAL PURE FUNCTIONS ----------------- **/


  function navIncreasedOrEqual(uint newNav, uint oldNav) internal pure returns (bool) {

    if (newNav >= oldNav) {
      return true;
    }

    return false;

  }


  function lookForSingleCoverage(
    uint valueToWithdraw,
    uint[] memory opportunitiesTokenValues
  )
    internal
    pure
    returns (uint)
  {

   for (uint i = 0; i < opportunitiesTokenValues.length; i++) {

       uint opportunityTokenValue = opportunitiesTokenValues[i];

       if (valueToWithdraw <= opportunityTokenValue) {

         return i;

       }

     }

     return opportunitiesTokenValues.length;

  }


  function convertCoinStandardToBool(uint coinStandard) internal pure returns (bool) {

    if (coinStandard == ETH_STANDARD) {
      return false;
    }

    return true;

  }


  function ceilOrMax(uint a, uint m, uint max) internal pure returns (uint) {
     uint ceiling = (a.add(m).sub(1)).div(m).mul(m);

     return Math.min(ceiling, max);
 }

}
