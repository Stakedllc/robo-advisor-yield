const ERC20_DAI = artifacts.require('TestDAI');
const ERC20_USDC = artifacts.require('TestUSDC');
const Constants = require('./constants.js');
const Deployed = Constants.TEST_ADDRESSES;

let dai, usdc;

ERC20_DAI.at(Deployed.DAI_TOKEN).then( (contract, err) => { dai = contract });
ERC20_USDC.at(Deployed.USDC_TOKEN).then( (contract, err) => { usdc = contract });


async function getDAI(
  receiver,
  amount
) {

  await dai.issueTo(
    web3.utils.toWei(amount, 'ether'),
    { from: receiver }
  );

}


async function getUSDC(
  receiver,
  amount
) {

  await usdc.issueTo(
    web3.utils.toWei(amount, 'mwei'),
    { from: receiver }
  );

}


async function getCoins(
  receiver,
  amount
) {

   await Promise.all([
     getDAI(dai, receiver, amount),
     getUSDC(usdc, receiver, amount)
   ]);

}


async function approveDAI(to, from, value) {

  await dai.approve(
    to,
    web3.utils.toWei(value, 'ether'), { from: from }
  );

}


async function approveUSDC(to, from, value) {

  await usdc.approve(
    to,
    web3.utils.toWei(value, 'mwei'), { from: from }
  );

}


async function getDAIBalance(address) {

  let balance = await dai.balanceOf.call(address);
  return balance;

}


module.exports = {
  getDAI,
  getUSDC,
  getCoins,
  approveDAI,
  approveUSDC,
  getDAIBalance
 };
