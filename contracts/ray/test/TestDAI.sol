pragma solidity 0.4.25;

import "../protocol/impl/openzeppelin/ERC20/ERC20.sol";

contract TestDAI is ERC20 {

  function issueTo(uint256 amount) public {

      super._mint(msg.sender, amount);

    }

}
