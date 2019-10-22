const PortfolioManagerContract = artifacts.require('PortfolioManager');
const Lend = require('./Lend.js')
const Coins = require('../helpers/Coins.js')
const Constants = require('../helpers/constants.js');
const Deployed = Constants.TEST_ADDRESSES;
const OpportunityIds = Constants.TEST_OPPORTUNITY_IDS;

let portfolioManager;

PortfolioManagerContract.at(Deployed.PORTFOLIO_MANAGER).then( (contract, err) => { portfolioManager = contract });


async function mintEthRAY(
  portfolioId,
  funder,
  beneficiary,
  value
) {

  convertedValue = web3.utils.toWei(value.toString(), 'ether');

  let tx = await portfolioManager.mint(
    portfolioId,
    beneficiary,
    convertedValue,
    { from: funder, value: convertedValue }
  );

  await Lend.lend(portfolioId, OpportunityIds.ETH.GENERIC, convertedValue);

  return tx.logs[0].args.tokenId;

}


async function mintDaiRAY(
  portfolioId,
  funder,
  beneficiary,
  value
) {

  await Coins.getDAI(funder, value);
  await Coins.approveDAI(portfolioManager.address, funder, value);

  let convertedValue = web3.utils.toWei(value.toString(), 'ether');

  let tx = await portfolioManager.mint(
    portfolioId,
    beneficiary,
    convertedValue,
    { from: funder, value: 0 }
  );

  await Lend.lend(portfolioId, OpportunityIds.DAI.GENERIC, convertedValue);

  return tx.logs[0].args.tokenId;

}


async function mintUsdcRAY(
  portfolioId,
  funder,
  beneficiary,
  value
) {

  await Coins.getUSDC(funder, value);
  await Coins.approveUSDC(portfolioManager.address, funder, value);

  let convertedValue = web3.utils.toWei(value.toString(), 'mwei');

  let tx = await portfolioManager.mint(
    portfolioId,
    beneficiary,
    convertedValue,
    { from: funder, value: 0 }
  );

  await Lend.lend(portfolioId, OpportunityIds.USDC.GENERIC, convertedValue);

  return tx.logs[0].args.tokenId;

}


module.exports = { mintEthRAY, mintDaiRAY, mintUsdcRAY };
