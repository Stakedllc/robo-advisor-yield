pragma solidity 0.4.25;

interface CompoundInterface {

    // for ETH/erc-20, returns in units of wei
    function exchangeRateCurrent() external returns (uint);

    // for ETH/erc-20, pass in the amount we want to withdraw
    function redeemUnderlying(uint redeemAmount) external returns (uint);

    // for ETH/erc-20
    function balanceOf(address account) external returns (uint);


    function getCash() external returns (uint);


    function totalBorrowsCurrent() external returns (uint);


    function supplyRatePerBlock() external view returns (uint);


    function totalReserves() external returns (uint);


    function totalSupply() external returns (uint);


}
