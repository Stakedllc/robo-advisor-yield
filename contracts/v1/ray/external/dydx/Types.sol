pragma solidity 0.4.25;
pragma experimental ABIEncoderV2;

library Types {


// ============ AssetAmount ============

    enum AssetDenomination {
        Wei, // the amount is denominated in wei
        Par  // the amount is denominated in par
    }

    enum AssetReference {
        Delta, // the amount is given as a delta from the current value
        Target // the amount is given as an exact number to end up at
    }

    struct AssetAmount {
        bool sign; // true if positive
        AssetDenomination denomination;
        AssetReference ref;
        uint256 value;
    }

    // Individual token amount for an account
    struct Wei {
        bool sign; // true if positive
        uint256 value;
     }

     // Individual principal amount for an account
    struct Par {
        bool sign; // true if positive
        uint128 value;
     }

     // Total borrow and supply values for a market
     // required for off-chain queries
     struct TotalPar {
       uint128 borrow;
       uint128 supply;
     }

     struct Rate {
       uint256 value;
     }

     struct D256 {
       uint256 value;
   }

   struct Index {
       uint96 borrow;
       uint96 supply;
       uint32 lastUpdate;
   }

}
