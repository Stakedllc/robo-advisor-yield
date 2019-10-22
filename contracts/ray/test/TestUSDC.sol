pragma solidity 0.4.25;

import "../protocol/impl/openzeppelin/ERC20/ERC20Detailed.sol";
import "../protocol/impl/openzeppelin/ERC20/ERC20.sol";


contract TestUSDC is ERC20, ERC20Detailed {

  constructor()
  ERC20Detailed("TestUSDC", "TUSDC", 6)
  public
  {}


  function issueTo(uint256 amount) public {

      super._mint(msg.sender, amount);

    }

}
