pragma solidity 0.4.25;

interface CompoundV2Erc20 {

    // for erc-20 lending
    function mint(uint mintAmount) external returns (uint);

}
