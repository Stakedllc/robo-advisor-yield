const chai = require('chai');
chai.use(require('chai-bignumber')());
chai.use(require('chai-as-promised'));

const expect = chai.expect;
const BigNumber = require('bignumber.js');
const Mint = require('./actions/Mint.js');
const Coins = require('./helpers/Coins.js');
const RAYUtils = require('./helpers/RAYUtils.js');
const Evm = require('./helpers/Evm.js');
const Constants = require('./helpers/constants.js');
const Deployed = Constants.TEST_ADDRESSES;
const DaiPortfolioIds = Constants.PORTFOLIO_IDS.DAI;

const BasicRAYProxyContract = artifacts.require('BasicRAYProxy');

let basicRAYProxy, rayTokenId;


/**
 * @notice  Example of RAY Integration
 */

contract("#RAY Smart Contract Integration", async accounts => {

  const USER_ONE = accounts[1].toLowerCase();

  before(async () => {

    await Evm.resetEVM();

    basicRAYProxy = await BasicRAYProxyContract.new(Deployed.STORAGE);

  });

  describe("Third-party RAY mint", () => {

    it("should mint one RAY - value of 1 DAI - in DAI Bzx/Compound/Dydx Portfolio", async () => {

      let value = '1';

      await Coins.getDAI(USER_ONE, value);
      await Coins.approveDAI(basicRAYProxy.address, USER_ONE, value);

      let tx = await basicRAYProxy.mint(
        DaiPortfolioIds.BZX_COMPOUND_DYDX,
        USER_ONE,
        web3.utils.toWei(value, 'ether'),
        { from: USER_ONE, value: 0 }
      );

      rayTokenId = tx.logs[0].args.tokenId;

      let [
        tokenValue,
        owner
      ] =
      await Promise.all([
        RAYUtils.getRAYTokenValue(DaiPortfolioIds.BZX_COMPOUND_DYDX, rayTokenId),
        basicRAYProxy.rayTokens.call(rayTokenId)
      ]);

      expect(rayTokenId).to.not.be.equal(Constants.NULL_BYTES);
      expect(tokenValue).to.be.bignumber.equal(web3.utils.toWei(value, 'ether'));
      expect(owner.toLowerCase()).to.be.equal(USER_ONE.toLowerCase());

    });

  });


  describe("Third-party RAY deposit", () => {

    it("should deposit 2 DAI more to existing DAI RAY token", async () => {

      let value = '2';
      let tokenValueBefore = await RAYUtils.getRAYTokenValue(DaiPortfolioIds.BZX_COMPOUND_DYDX, rayTokenId);

      await Coins.getDAI(USER_ONE, value);
      await Coins.approveDAI(basicRAYProxy.address, USER_ONE, value);

      let tx = await basicRAYProxy.deposit(
        rayTokenId,
        web3.utils.toWei(value, 'ether'),
        { from: USER_ONE, value: 0 }
      );

      let tokenValueAfter = await RAYUtils.getRAYTokenValue(DaiPortfolioIds.BZX_COMPOUND_DYDX, rayTokenId);

      expect(tokenValueAfter).to.be.bignumber.equal((new BigNumber(web3.utils.toWei(value, 'ether'))).plus(tokenValueBefore));

    });

  });


  describe("Third-party RAY redeem", () => {

    it("should withdraw 3 DAI from DAI RAY token", async () => {

      let value = web3.utils.toWei('3', 'ether');
      let daiBalanceBefore = await Coins.getDAIBalance(USER_ONE);

      let tx = await basicRAYProxy.redeem(
        rayTokenId,
        value,
        USER_ONE,
        { from: USER_ONE, value: 0 }
      );

      let daiBalanceAfter = await Coins.getDAIBalance(USER_ONE);

      expect(daiBalanceAfter.toString()).to.be.bignumber.equal((new BigNumber(value)).plus(daiBalanceBefore));

    });

  });

});
