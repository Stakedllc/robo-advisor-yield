const OracleContract = artifacts.require('Oracle');
const Constants = require('../helpers/constants.js');
const Deployed = Constants.TEST_ADDRESSES;

let oracle;

OracleContract.at(Deployed.ORACLE).then( (contract, err) => { oracle = contract });


async function lend(
  portfolioId,
  opportunityId,
  value
) {

  await oracle.lend(portfolioId, opportunityId, Deployed.OPPORTUNITY, value);

}

module.exports = { lend };
