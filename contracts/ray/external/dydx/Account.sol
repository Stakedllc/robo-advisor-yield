pragma solidity 0.4.25;
pragma experimental ABIEncoderV2;

library Account {

	// Represents the unique key that specifies an account
   struct Info {
	   address owner;  // The address that owns the account
	   uint256 number; // A nonce that allows a single address to control many accounts
   }

}
