pragma solidity 0.4.25;

interface BzxEthInterface {

  function mintWithEther(address receiver) external payable returns (uint256 mintAmount);

  function burnToEther(address /*payable*/ receiver, uint256 burnAmount) external returns (uint256 loanAmountPaid);

}
