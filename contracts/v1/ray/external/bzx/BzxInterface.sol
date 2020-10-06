pragma solidity 0.4.25;

interface BzxInterface {

  function assetBalanceOf(address _owner) external view returns (uint256);

  function marketLiquidity() external view returns (uint256);

  function tokenPrice() external view returns (uint256);

  function supplyInterestRate() external view returns (uint256);

  function totalAssetSupply() external view returns (uint256);

  function totalAssetBorrow() external view returns (uint256);

}
