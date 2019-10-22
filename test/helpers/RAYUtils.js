const NAVCalculatorContract = artifacts.require('NAVCalculator');
const RAYTokenContract = artifacts.require('RAYToken');
const Constants = require('./constants.js');
const Deployed = Constants.TEST_ADDRESSES;

let navCalculator, rayToken;

NAVCalculatorContract.at(Deployed.NAV_CALCULATOR).then( (contract, err) => { navCalculator = contract });
RAYTokenContract.at(Deployed.RAY_TOKEN).then( (contract, err) => { rayToken = contract });


async function getRAYTokenValue(portfolioId, rayTokenId) {

  let result = await navCalculator.getTokenValue.call(portfolioId, rayTokenId);
  return result[0].toString();

}


async function getRAYTokenOwner(rayTokenId) {

  let owner = await rayToken.ownerOf.call(rayTokenId);
  return owner;

}


module.exports = { getRAYTokenValue, getRAYTokenOwner };
