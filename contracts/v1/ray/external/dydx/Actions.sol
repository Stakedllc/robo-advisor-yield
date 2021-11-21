pragma solidity 0.4.25;
pragma experimental ABIEncoderV2;

import { Types } from "./Types.sol";

library Actions {


	enum ActionType {
        Deposit,   // supply tokens
        Withdraw,  // borrow tokens
        Transfer,  // transfer balance between accounts
        Buy,       // buy an amount of some token (externally)
        Sell,      // sell an amount of some token (externally)
        Trade,     // trade tokens against another account
        Liquidate, // liquidate an undercollateralized or expiring account
        Vaporize,  // use excess tokens to zero-out a completely negative account
        Call       // send arbitrary data to an address
    }


	/*
	* Arguments that are passed to Solo in an ordered list as part of a single operation.
	* Each ActionArgs has an actionType which specifies which action struct that this data will be
	* parsed into before being processed.
	*/
   struct ActionArgs {
	   ActionType actionType;
	   uint256 accountId;
	   Types.AssetAmount amount;
	   uint256 primaryMarketId;
	   uint256 secondaryMarketId;
	   address otherAddress;
	   uint256 otherAccountId;
	   bytes data;
   }

}
