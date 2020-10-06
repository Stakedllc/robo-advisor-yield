pragma solidity 0.4.25;

interface BzxErc20Interface {

  function mint(address receiver, uint256 depositAmount) external returns (uint256 mintAmount); // erc20

  function burn(address receiver, uint256 burnAmount) external returns (uint256 loanAmountPaid);

}
