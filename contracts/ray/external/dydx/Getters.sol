pragma solidity 0.4.25;
pragma experimental ABIEncoderV2;

import "./Account.sol";
import "./Types.sol";

contract Getters {


   /**
   * Get an account's summary for each market.
   *
   * param  account  The account to query
   * @return          The following values:
   *                   - The ERC20 token address for each market
   *                   - The account's principal value for each market
   *                   - The account's (supplied or borrowed) number of tokens for each market
   */
    function getAccountBalances(
      Account.Info memory /*account*/
    )
      public
      view
      returns
    (
          address[] memory,
          Types.Par[] memory,
          Types.Wei[] memory
      )
      {}


    // get amount borrowed/suppllied
    function getMarketTotalPar(
      uint256 marketId
    )
      public
      view
      returns (Types.TotalPar memory)
    {}


    /**
    * Get the current borrower interest rate for a market.
    *
    * @param  marketId  The market to query
    * @return           The current interest rate
    */
   function getMarketInterestRate(
       uint256 marketId
   )
       public
       view
       returns (Types.Rate memory)
   {}


   /**
    * Get the global earnings-rate variable that determines what percentage of the interest paid
    * by borrowers gets passed-on to suppliers.
    *
    * @return  The global earnings rate
    */
   function getEarningsRate()
       public
       view
       returns (Types.D256 memory)
   {}


   /**
     * Get the most recently cached interest index for a market.
     *
     * @param  marketId  The market to query
     * @return           The most recent index
     */
    function getMarketCachedIndex(
        uint256 marketId
    )
        public
        view
        returns (Types.Index memory)
    {}

}
