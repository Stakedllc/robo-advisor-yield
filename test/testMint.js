const chai = require('chai');
chai.use(require('chai-bignumber')());
chai.use(require('chai-as-promised'));

const expect = chai.expect;
const BigNumber = require('bignumber.js');
const Mint = require('./actions/Mint.js');
const RAYUtils = require('./helpers/RAYUtils.js');
const Evm = require('./helpers/Evm.js');
const Constants = require('./helpers/constants.js');
const Deployed = Constants.TEST_ADDRESSES;
const EthPortfolioIds = Constants.PORTFOLIO_IDS.ETH;
const DaiPortfolioIds = Constants.PORTFOLIO_IDS.DAI;
const UsdcPortfolioIds = Constants.PORTFOLIO_IDS.USDC;


/**
 * @notice  Minting RAY tokens / creating RAY positions
 *
 *          Example of minting different valid RAY positions.
 */

contract("#Minting RAY Tokens", async accounts => {

  const USER_ONE = accounts[1].toLowerCase();

  before(async () => {

    await Evm.resetEVM();
    await Evm.snapshot();

  });

  beforeEach(async () => {

    await Evm.resetEVM();

  });

  describe("Valid ETH RAY mint", () => {

    it("should mint one RAY in ETH Bzx/Compound/Dydx Portfolio", async () => {

      let value = '1';

      let rayTokenId = await Mint.mintEthRAY(
        EthPortfolioIds.BZX_COMPOUND_DYDX,
        USER_ONE,
        USER_ONE,
        value
      );

      let [
        tokenValue,
        owner
      ] =
      await Promise.all([
        RAYUtils.getRAYTokenValue(EthPortfolioIds.BZX_COMPOUND_DYDX, rayTokenId),
        RAYUtils.getRAYTokenOwner(rayTokenId)
      ]);

      expect(rayTokenId).to.not.be.equal(Constants.NULL_BYTES);
      expect(tokenValue).to.be.bignumber.equal(web3.utils.toWei(value, 'ether'));
      expect(owner.toLowerCase()).to.be.equal(USER_ONE.toLowerCase());

    });

  });


  describe("Valid DAI RAY mint", () => {

    it("should mint one RAY in DAI Bzx/Compound/Dydx Portfolio", async () => {

      let value = '1';

      let rayTokenId = await Mint.mintDaiRAY(
        DaiPortfolioIds.BZX_COMPOUND_DYDX,
        USER_ONE,
        USER_ONE,
        value
      );

      let [
        tokenValue,
        owner
      ] =
      await Promise.all([
        RAYUtils.getRAYTokenValue(DaiPortfolioIds.BZX_COMPOUND_DYDX, rayTokenId),
        RAYUtils.getRAYTokenOwner(rayTokenId)
      ]);


      expect(rayTokenId).to.not.be.equal(Constants.NULL_BYTES);
      expect(tokenValue).to.be.bignumber.equal(web3.utils.toWei(value, 'ether'));
      expect(owner.toLowerCase()).to.be.equal(USER_ONE.toLowerCase());

    });

  });


  describe("Valid USDC RAY mint", () => {

    it("should mint one RAY in USDC Bzx/Compound/Dydx Portfolio", async () => {

      let value = '1';

      let rayTokenId = await Mint.mintUsdcRAY(
        UsdcPortfolioIds.BZX_COMPOUND_DYDX,
        USER_ONE,
        USER_ONE,
        value
      );

      let [
        tokenValue,
        owner
      ] =
      await Promise.all([
        RAYUtils.getRAYTokenValue(UsdcPortfolioIds.BZX_COMPOUND_DYDX, rayTokenId),
        RAYUtils.getRAYTokenOwner(rayTokenId)
      ]);

      expect(rayTokenId).to.not.be.equal(Constants.NULL_BYTES);
      expect(tokenValue).to.be.bignumber.equal(web3.utils.toWei(value, 'mwei'));
      expect(owner.toLowerCase()).to.be.equal(USER_ONE.toLowerCase());

    });

  });


});
