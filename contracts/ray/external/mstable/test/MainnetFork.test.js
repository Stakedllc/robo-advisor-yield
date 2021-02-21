const { expect } = require("chai");
const hre = require("hardhat");
const axios = require("axios");

const ethers = hre.ethers;

const ether = (n) => {
  return ethers.utils.parseEther(n.toString());
};

const tokens = (n) => ether(n);

const fromWei = (n) => {
  return ethers.utils.formatEther(n);
};

const advanceBlocks = async (blocks) => {
  for (i = 0; i < blocks; i++) {
    await hre.network.provider.send("evm_increaseTime", [13]);
    await hre.network.provider.send("evm_mine");
  }
};

const getPrincipal = async (principalAddress, from, to, amount) => {
  await hre.network.provider.request({
    method: "hardhat_impersonateAccount",
    params: [from],
  });

  const contract = new ethers.Contract(principalAddress, ERC20Abi, ethers.provider);

  balance = await contract.balanceOf(to);
  console.log(balance.toString(), "Principal balance before transfer");

  signer = await ethers.provider.getSigner(from);
  contractSigned = contract.connect(signer);

  await contractSigned.transfer(to, amount, {
    from: from,
  });

  balance = await contract.balanceOf(to);

  console.log(balance.toString(), "Principal balance after transfer");
};

describe("MyOpportunity", function () {
  let mStable;
  const deployer = "0x4e9b45b1b16dd4ddb76cf9564563edf2d1ebc41e"; // first account

  const sUSD = "0x57ab1ec28d129707052df4df418d58a2d46d5f51";
  const USDC = "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48";
  const TUSD = "0x0000000000085d4780B73119b644AE5ecd22b376";
  const USDT = "0xdac17f958d2ee523a2206206994597c13d831ec7";
  const mUSD = "0xe2f2a5c287993345a840db3b0845fbc70f5935a5";

  const helperAddress = "0xe15aad5d6b7433e5988415274529311f6bf6e8a3";
  const proxy = "0xe2f2a5C287993345a840Db3B0845fbC70f5935a5";

  const saveAddress = "0x30647a72Dc82d7Fbb1123EA74716aB8A317Eac19";

  const storageRayMockUp = "0x948d3D9900bC9C428F5c69dccf6b7Ea24fb6b810";

  //Utilities addresses from where we are going to get the principal

  const getTUSD = "0x270cd0b43f6fE2512A32597C7A05FB01eE6ec8E1";
  const getUSDC = "0x0290135299063d0bfe456603310ce6a4a614a8ff";
  const getUSDT = "0x3567Cafb8Bf2A83bBEa4E79f3591142fb4EBe86d";
  const getSUSD = "0x49BE88F0fcC3A8393a59d3688480d7D253C37D2A";

  const options = { gasLimit: 5000000 };

  let TUSDSigned;
  let USDCSigned;
  let USDTSigned;
  let sUSDSigned;
  let opportunity;
  let helperContract;
  let saveContract;

  beforeEach(async () => {
    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [deployer],
    });

    signer = await ethers.provider.getSigner(deployer);

    const mUSDContract = new ethers.Contract(mUSD, ERC20Abi, ethers.provider);
    const mUSDSigned = mUSDContract.connect(signer);

    const USDCContract = new ethers.Contract(USDC, ERC20Abi, ethers.provider);
    USDCSigned = USDCContract.connect(signer);

    const USDTContract = new ethers.Contract(USDT, ERC20Abi, ethers.provider);
    USDTSigned = USDTContract.connect(signer);

    const sUSDContract = new ethers.Contract(sUSD, ERC20Abi, ethers.provider);
    sUSDSigned = sUSDContract.connect(signer);

    const TUSDContract = new ethers.Contract(TUSD, ERC20Abi, ethers.provider);
    TUSDSigned = TUSDContract.connect(signer);

    saveContract = new ethers.Contract(saveAddress, SaveAbi, ethers.provider);

    helperContract = new ethers.Contract(
      helperAddress,
      HelperAbi,
      ethers.provider
    );

    const MStable = await ethers.getContractFactory("MStableOpportunityAll");
    mStable = await MStable.deploy();

    await mStable.deployed();
    expect(mStable.address);

    const opportunityContract = new ethers.Contract(
      mStable.address,
      OpportunityAbi,
      ethers.provider
    );

    opportunity = opportunityContract.connect(signer);

    // use USDC or DAI address
    await opportunity.initialize(
      storageRayMockUp,
      [sUSD, TUSD, USDC, USDT],
      [proxy, proxy, proxy, proxy],
      saveAddress,
      helperAddress,
      mUSD
    );

    await mUSDSigned.approve(proxy, tokens(9900));

    await mUSDSigned.approve(saveAddress, tokens(9990));

    await opportunity.approveOnce(TUSD);

    await opportunity.approveEach(TUSD);

    await opportunity.approveEach(USDC);

    await opportunity.approveEach(USDT);

    await opportunity.approveEach(sUSD);

    await mUSDSigned.approve(mStable.address, tokens(9990));

    console.log("MyOpportunity deployed to:", mStable.address);
  });

  xit("Should get TUSD, supply and withdraw", async function () {
    amount = tokens(1656);
    await getPrincipal(TUSD, getTUSD, deployer, amount);

    result = await TUSDSigned.approve(mStable.address, tokens(9990));
    await result.wait();

    result = await saveContract.balanceOf(mStable.address);
    console.log(result.toString(), "opportunity balance");

    result = await saveContract.creditsToUnderlying(result);
    console.log(result.toString(), "creditsToUnderlying");

    result = await opportunity.supply(
      TUSD,
      ethers.utils.parseEther("1000"),
      true,
      { from: deployer }
    );
    await result.wait();

    result = await helperContract.getSaveRedeemInput(
      saveAddress,
      ethers.utils.parseEther("1000"),
      options
    );
    console.log(result.toString(), "credits calculated with helper");

    result = await saveContract.balanceOf(mStable.address);
    console.log(result.toString(), "opportunity balance");
    result = await saveContract.creditsToUnderlying(result);
    console.log(result.toString(), "creditsToUnderlying");

    result = await opportunity.withdraw(TUSD, deployer, result, true, options);
    await result.wait();

    result = await TUSDSigned.balanceOf(deployer);
    console.log(result.toString(), "receiver TUSD balance");
  });

  xit("Should get USDC, supply and withdraw", async function () {
    amount = 1000000;

    await getPrincipal(USDC, getUSDC, deployer, amount);

    result = await USDCSigned.approve(mStable.address, tokens(9990));
    await result.wait();

    result = await saveContract.balanceOf(mStable.address);
    console.log(result.toString(), "opportunity balance");

    result = await saveContract.creditsToUnderlying(result);
    console.log(result.toString(), "creditsToUnderlying");

    result = await opportunity.supply(USDC, amount, false, { from: deployer });

    await result.wait();

    result = await helperContract.getSaveRedeemInput(
      saveAddress,
      amount,
      options
    );
    console.log(result.toString(), "credits calculated with helper");

    result = await saveContract.balanceOf(mStable.address);
    console.log(result.toString(), "opportunity balance");
    result = await saveContract.creditsToUnderlying(result);
    console.log(result.toString(), "creditsToUnderlying");

    result = await opportunity.withdraw(USDC, deployer, result, false, options);
    await result.wait();

    result = await USDCSigned.balanceOf(deployer);
    console.log(result.toString(), "receiver USDC balance");
  });

  xit("Should get sUSD, supply and withdraw", async function () {
    amount = tokens(8888);

    await getPrincipal(sUSD, getSUSD, deployer, amount);

    result = await sUSDSigned.approve(mStable.address, tokens(9990));
    await result.wait();

    result = await saveContract.balanceOf(mStable.address);
    console.log(result.toString(), "opportunity balance");

    result = await saveContract.creditsToUnderlying(result);
    console.log(result.toString(), "creditsToUnderlying");

    result = await opportunity.supply(
      sUSD,
      ethers.utils.parseEther("1000"),
      true,
      { from: deployer }
    );

    await result.wait();

    result = await helperContract.getSaveRedeemInput(
      saveAddress,
      ethers.utils.parseEther("1000"),
      options
    );
    console.log(result.toString(), "credits calculated with helper");

    result = await saveContract.balanceOf(mStable.address);
    console.log(result.toString(), "opportunity balance");
    result = await saveContract.creditsToUnderlying(result);
    console.log(result.toString(), "creditsToUnderlying");

    result = await opportunity.withdraw(sUSD, deployer, result, true, options);
    receipt = await result.wait();

    result = await sUSDSigned.balanceOf(deployer);
    console.log(result.toString(), "receiver sUSD balance");
  });
  
  // this one throws:  Error: Transaction reverted: function returned an unexpected amount of data
  // which is weird because it's the same code for all of them, the error is when trying transferFrom in the supply function.
  it("Should get USDT, supply and withdraw", async function () {
    amount = 1000000;

    await getPrincipal(USDT, getUSDT, deployer, amount);

    result = await USDTSigned.approve(mStable.address, amount, {
      from: deployer,
    });
    await result.wait();

    result = await saveContract.balanceOf(mStable.address);
    console.log(result.toString(), "opportunity balance");

    result = await saveContract.creditsToUnderlying(result);
    console.log(result.toString(), "creditsToUnderlying");

    result = await opportunity.supply(USDT, amount, false, {
      from: deployer,
      gasLimit: 5000000,
    });
    //console.log(result);

    await result.wait();

    result = await helperContract.getSaveRedeemInput(
      saveAddress,
      amount,
      options
    );
    console.log(result.toString(), "credits calculated with helper");

    result = await saveContract.balanceOf(mStable.address);
    console.log(result.toString(), "opportunity balance");
    result = await saveContract.creditsToUnderlying(result);
    console.log(result.toString(), "creditsToUnderlying");

    result = await opportunity.withdraw(USDT, deployer, result, false, options);
    await result.wait();

    result = await USDTSigned.balanceOf(deployer);
    console.log(result.toString(), "receiver USDT balance");
  });

  xit("Should get TUSD, supply, check OFFchain data and then withdraw", async function () {
    amount = tokens(1656);
    await getPrincipal(TUSD, getTUSD, deployer, amount);

    result = await TUSDSigned.approve(mStable.address, tokens(9990));
    await result.wait();

    result = await opportunity.supply(
      TUSD,
      ethers.utils.parseEther("1000"),
      true,
      { from: deployer }
    );

    await result.wait();

    result = await helperContract.getSaveRedeemInput(
      saveAddress,
      ethers.utils.parseEther("1000"),
      options
    );
    console.log(result.toString(), "credits calculated with helper");

    result = await saveContract.balanceOf(mStable.address);
    console.log(result.toString(), "opportunity balance");
    result = await saveContract.creditsToUnderlying(result);
    console.log(result.toString(), "creditsToUnderlying");

    const basketManagerAddress = "0x66126B4aA2a1C07536Ef8E5e8bD4EfDA1FdEA96D";

    const basketContract = new ethers.Contract(
      basketManagerAddress,
      BasketManagerAbi,
      ethers.provider
    );

    const getDemand = async () => {
      result = await helperContract.getSaveBalance(
        saveAddress,
        mStable.address
      );
      console.log(result.toString(), "credits balance in mUSD wei");
      result = await helperContract.getSaveRedeemInput(saveAddress, result);
      console.log(result.toString(), "credits");
    };

    await getDemand();

    const getLiquidity = async (bAsset) => {
      result = await basketContract.getBasset(bAsset);
      console.log(result.vaultBalance.toString(), `${bAsset} total liquidity`);

      return result.vaultBalance.toString();
    };

    await getLiquidity(sUSD);
    await getLiquidity(USDC);
    await getLiquidity(TUSD);
    await getLiquidity(USDT);

    const getRate = async () => {
      axios
        .post(
          "https://api.thegraph.com/subgraphs/name/mstable/mstable-protocol",
          {
            query: `
    {
      savingsContract(id:"0x30647a72dc82d7fbb1123ea74716ab8a317eac19")  {
        
       latestExchangeRate{
         rate
         timestamp
       }
       exchangeRate24hAgo{
         rate
         timestamp
       }
    
     
     }
      }
    `,
          }
        )
        .then((res) => {
          const data = res.data.data.savingsContract;

          const latestExchangeRate = parseFloat(data.latestExchangeRate.rate);
          const exchangeRate24hAgo = parseFloat(data.exchangeRate24hAgo.rate);

          const result = (latestExchangeRate - exchangeRate24hAgo) * 365 * 1000;
          console.log(
            result,
            "annual APR %, based on the last 24hours difference"
          );
          return result;
        })
        .catch((error) => {
          console.error(error);
          return error;
        });
    };

    await getRate();

    const getSupply = async (bAsset) => {
      saveBalance = await helperContract.getSaveBalance(
        saveAddress,
        mStable.address
      );
      console.log(saveBalance.toString(), "saver balance in mUSD wei");

      result = await helperContract.getRedeemValidity(
        mUSD,
        saveBalance,
        bAsset
      );
      console.log(
        result.output.toString(),
        `actual value that will be credited for asset ${bAsset}`
      );
      console.log(
        result.bassetQuantityArg.toString(),
        `input argument for redeeming, correspond to the supplied amount independently from which asset we deposited`
      );

      return result.bassetQuantityArg; // or result.output.toString() depending which one should be returned for the bot
    };

    // credits can be redeemed fot any assets, independetly from which asset we deposited. When calling getSupply we have to rememeber that
    // this is the possible supply but if we redeem from one of them it will be affected.
    result = await getSupply(TUSD);

    result = await opportunity.withdraw(TUSD, deployer, result, true, options);
    receipt = await result.wait();

    result = await TUSDSigned.balanceOf(deployer);
    console.log(result.toString(), "receiver TUSD balance");
  });

});

const OpportunityAbi = [
  {
    payable: true,
    stateMutability: "payable",
    type: "fallback",
  },
  {
    constant: false,
    inputs: [
      {
        internalType: "address[]",
        name: "principalTokens",
        type: "address[]",
      },
      {
        internalType: "address[]",
        name: "otherContracts",
        type: "address[]",
      },
    ],
    name: "addPrincipalTokens",
    outputs: [],
    payable: false,
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    constant: false,
    inputs: [
      {
        internalType: "address",
        name: "token",
        type: "address",
      },
    ],
    name: "approveEach",
    outputs: [],
    payable: false,
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    constant: false,
    inputs: [
      {
        internalType: "address",
        name: "token",
        type: "address",
      },
    ],
    name: "approveOnce",
    outputs: [],
    payable: false,
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    constant: true,
    inputs: [],
    name: "helper",
    outputs: [
      {
        internalType: "contract IMStableHelper",
        name: "",
        type: "address",
      },
    ],
    payable: false,
    stateMutability: "view",
    type: "function",
  },
  {
    constant: false,
    inputs: [
      {
        internalType: "address",
        name: "storage_contract",
        type: "address",
      },
      {
        internalType: "address[]",
        name: "principalToken",
        type: "address[]",
      },
      {
        internalType: "address[]",
        name: "otherToken",
        type: "address[]",
      },
      {
        internalType: "address",
        name: "_savingsContract",
        type: "address",
      },
      {
        internalType: "address",
        name: "_mStableHelper",
        type: "address",
      },
      {
        internalType: "address",
        name: "_mUSD",
        type: "address",
      },
    ],
    name: "initialize",
    outputs: [],
    payable: false,
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    constant: true,
    inputs: [],
    name: "mUSD",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    payable: false,
    stateMutability: "view",
    type: "function",
  },
  {
    constant: true,
    inputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    name: "markets",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    payable: false,
    stateMutability: "view",
    type: "function",
  },
  {
    constant: true,
    inputs: [],
    name: "rayStorage",
    outputs: [
      {
        internalType: "contract IStorage",
        name: "",
        type: "address",
      },
    ],
    payable: false,
    stateMutability: "view",
    type: "function",
  },
  {
    constant: true,
    inputs: [],
    name: "saveAddress",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    payable: false,
    stateMutability: "view",
    type: "function",
  },
  {
    constant: true,
    inputs: [],
    name: "savingsContract",
    outputs: [
      {
        internalType: "contract ISavingsContract",
        name: "",
        type: "address",
      },
    ],
    payable: false,
    stateMutability: "view",
    type: "function",
  },
  {
    constant: false,
    inputs: [
      {
        internalType: "address",
        name: "token",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "amount",
        type: "uint256",
      },
      {
        internalType: "bool",
        name: "isERC20",
        type: "bool",
      },
    ],
    name: "supply",
    outputs: [],
    payable: true,
    stateMutability: "payable",
    type: "function",
  },
  {
    constant: false,
    inputs: [
      {
        internalType: "address",
        name: "token",
        type: "address",
      },
      {
        internalType: "address",
        name: "beneficiary",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "amount",
        type: "uint256",
      },
      {
        internalType: "bool",
        name: "isERC20",
        type: "bool",
      },
    ],
    name: "withdraw",
    outputs: [],
    payable: false,
    stateMutability: "nonpayable",
    type: "function",
  },
];

const ERC20Abi = [
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "owner",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "spender",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "value",
        type: "uint256",
      },
    ],
    name: "Approval",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "from",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "to",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "value",
        type: "uint256",
      },
    ],
    name: "Transfer",
    type: "event",
  },
  {
    constant: true,
    inputs: [
      {
        internalType: "address",
        name: "owner",
        type: "address",
      },
      {
        internalType: "address",
        name: "spender",
        type: "address",
      },
    ],
    name: "allowance",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    payable: false,
    stateMutability: "view",
    type: "function",
  },
  {
    constant: false,
    inputs: [
      {
        internalType: "address",
        name: "spender",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "value",
        type: "uint256",
      },
    ],
    name: "approve",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
    payable: false,
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    constant: true,
    inputs: [
      {
        internalType: "address",
        name: "who",
        type: "address",
      },
    ],
    name: "balanceOf",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    payable: false,
    stateMutability: "view",
    type: "function",
  },
  {
    constant: true,
    inputs: [],
    name: "totalSupply",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    payable: false,
    stateMutability: "view",
    type: "function",
  },
  {
    constant: false,
    inputs: [
      {
        internalType: "address",
        name: "to",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "value",
        type: "uint256",
      },
    ],
    name: "transfer",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
    payable: false,
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    constant: false,
    inputs: [
      {
        internalType: "address",
        name: "from",
        type: "address",
      },
      {
        internalType: "address",
        name: "to",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "value",
        type: "uint256",
      },
    ],
    name: "transferFrom",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
    payable: false,
    stateMutability: "nonpayable",
    type: "function",
  },
];

const HelperAbi = [
  {
    constant: true,
    inputs: [
      { internalType: "address", name: "_mAsset", type: "address" },
      { internalType: "address", name: "_input", type: "address" },
      { internalType: "address", name: "_output", type: "address" },
    ],
    name: "getMaxSwap",
    outputs: [
      { internalType: "bool", name: "", type: "bool" },
      { internalType: "string", name: "", type: "string" },
      { internalType: "uint256", name: "", type: "uint256" },
      { internalType: "uint256", name: "", type: "uint256" },
    ],
    payable: false,
    stateMutability: "view",
    type: "function",
  },
  {
    constant: true,
    inputs: [
      { internalType: "address", name: "_mAsset", type: "address" },
      { internalType: "uint256", name: "_mAssetQuantity", type: "uint256" },
      { internalType: "address", name: "_outputBasset", type: "address" },
    ],
    name: "getRedeemValidity",
    outputs: [
      { internalType: "bool", name: "", type: "bool" },
      { internalType: "string", name: "", type: "string" },
      { internalType: "uint256", name: "output", type: "uint256" },
      { internalType: "uint256", name: "bassetQuantityArg", type: "uint256" },
    ],
    payable: false,
    stateMutability: "view",
    type: "function",
  },
  {
    constant: true,
    inputs: [
      {
        internalType: "contract ISavingsContract",
        name: "_save",
        type: "address",
      },
      { internalType: "address", name: "_user", type: "address" },
    ],
    name: "getSaveBalance",
    outputs: [{ internalType: "uint256", name: "", type: "uint256" }],
    payable: false,
    stateMutability: "view",
    type: "function",
  },
  {
    constant: true,
    inputs: [
      {
        internalType: "contract ISavingsContract",
        name: "_save",
        type: "address",
      },
      { internalType: "uint256", name: "_mAssetUnits", type: "uint256" },
    ],
    name: "getSaveRedeemInput",
    outputs: [{ internalType: "uint256", name: "", type: "uint256" }],
    payable: false,
    stateMutability: "view",
    type: "function",
  },
  {
    constant: true,
    inputs: [{ internalType: "address", name: "_mAsset", type: "address" }],
    name: "suggestMintAsset",
    outputs: [
      { internalType: "bool", name: "", type: "bool" },
      { internalType: "string", name: "", type: "string" },
      { internalType: "address", name: "", type: "address" },
    ],
    payable: false,
    stateMutability: "view",
    type: "function",
  },
  {
    constant: true,
    inputs: [{ internalType: "address", name: "_mAsset", type: "address" }],
    name: "suggestRedeemAsset",
    outputs: [
      { internalType: "bool", name: "", type: "bool" },
      { internalType: "string", name: "", type: "string" },
      { internalType: "address", name: "", type: "address" },
    ],
    payable: false,
    stateMutability: "view",
    type: "function",
  },
];

const BasketManagerAbi = [
  {
    anonymous: false,
    inputs: [],
    name: "BasketStatusChanged",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "address[]",
        name: "bAssets",
        type: "address[]",
      },
      {
        indexed: false,
        internalType: "uint256[]",
        name: "maxWeights",
        type: "uint256[]",
      },
    ],
    name: "BasketWeightsUpdated",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "bAsset",
        type: "address",
      },
      {
        indexed: false,
        internalType: "address",
        name: "integrator",
        type: "address",
      },
    ],
    name: "BassetAdded",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "bAsset",
        type: "address",
      },
    ],
    name: "BassetRemoved",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "bAsset",
        type: "address",
      },
      {
        indexed: false,
        internalType: "enum MassetStructs.BassetStatus",
        name: "status",
        type: "uint8",
      },
    ],
    name: "BassetStatusChanged",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "address",
        name: "account",
        type: "address",
      },
    ],
    name: "Paused",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "bAsset",
        type: "address",
      },
      {
        indexed: false,
        internalType: "bool",
        name: "enabled",
        type: "bool",
      },
    ],
    name: "TransferFeeEnabled",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "address",
        name: "account",
        type: "address",
      },
    ],
    name: "Unpaused",
    type: "event",
  },
  {
    constant: false,
    inputs: [
      {
        internalType: "address",
        name: "_bAsset",
        type: "address",
      },
      {
        internalType: "address",
        name: "_integration",
        type: "address",
      },
      {
        internalType: "bool",
        name: "_isTransferFeeCharged",
        type: "bool",
      },
    ],
    name: "addBasset",
    outputs: [
      {
        internalType: "uint8",
        name: "index",
        type: "uint8",
      },
    ],
    payable: false,
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    constant: true,
    inputs: [],
    name: "basket",
    outputs: [
      {
        internalType: "uint8",
        name: "maxBassets",
        type: "uint8",
      },
      {
        internalType: "bool",
        name: "undergoingRecol",
        type: "bool",
      },
      {
        internalType: "bool",
        name: "failed",
        type: "bool",
      },
      {
        internalType: "uint256",
        name: "collateralisationRatio",
        type: "uint256",
      },
    ],
    payable: false,
    stateMutability: "view",
    type: "function",
  },
  {
    constant: false,
    inputs: [],
    name: "collectInterest",
    outputs: [
      {
        internalType: "uint256",
        name: "interestCollected",
        type: "uint256",
      },
      {
        internalType: "uint256[]",
        name: "gains",
        type: "uint256[]",
      },
    ],
    payable: false,
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    constant: false,
    inputs: [
      {
        internalType: "uint8",
        name: "_bAssetIndex",
        type: "uint8",
      },
      {
        internalType: "address",
        name: "",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "_decreaseAmount",
        type: "uint256",
      },
    ],
    name: "decreaseVaultBalance",
    outputs: [],
    payable: false,
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    constant: false,
    inputs: [
      {
        internalType: "uint8[]",
        name: "_bAssetIndices",
        type: "uint8[]",
      },
      {
        internalType: "address[]",
        name: "",
        type: "address[]",
      },
      {
        internalType: "uint256[]",
        name: "_decreaseAmount",
        type: "uint256[]",
      },
    ],
    name: "decreaseVaultBalances",
    outputs: [],
    payable: false,
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    constant: false,
    inputs: [
      {
        internalType: "address",
        name: "_bAsset",
        type: "address",
      },
    ],
    name: "failBasset",
    outputs: [],
    payable: false,
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    constant: true,
    inputs: [],
    name: "getBasket",
    outputs: [
      {
        components: [
          {
            components: [
              {
                internalType: "address",
                name: "addr",
                type: "address",
              },
              {
                internalType: "enum MassetStructs.BassetStatus",
                name: "status",
                type: "uint8",
              },
              {
                internalType: "bool",
                name: "isTransferFeeCharged",
                type: "bool",
              },
              {
                internalType: "uint256",
                name: "ratio",
                type: "uint256",
              },
              {
                internalType: "uint256",
                name: "maxWeight",
                type: "uint256",
              },
              {
                internalType: "uint256",
                name: "vaultBalance",
                type: "uint256",
              },
            ],
            internalType: "struct MassetStructs.Basset[]",
            name: "bassets",
            type: "tuple[]",
          },
          {
            internalType: "uint8",
            name: "maxBassets",
            type: "uint8",
          },
          {
            internalType: "bool",
            name: "undergoingRecol",
            type: "bool",
          },
          {
            internalType: "bool",
            name: "failed",
            type: "bool",
          },
          {
            internalType: "uint256",
            name: "collateralisationRatio",
            type: "uint256",
          },
        ],
        internalType: "struct MassetStructs.Basket",
        name: "b",
        type: "tuple",
      },
    ],
    payable: false,
    stateMutability: "view",
    type: "function",
  },
  {
    constant: true,
    inputs: [
      {
        internalType: "address",
        name: "_bAsset",
        type: "address",
      },
    ],
    name: "getBasset",
    outputs: [
      {
        components: [
          {
            internalType: "address",
            name: "addr",
            type: "address",
          },
          {
            internalType: "enum MassetStructs.BassetStatus",
            name: "status",
            type: "uint8",
          },
          {
            internalType: "bool",
            name: "isTransferFeeCharged",
            type: "bool",
          },
          {
            internalType: "uint256",
            name: "ratio",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "maxWeight",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "vaultBalance",
            type: "uint256",
          },
        ],
        internalType: "struct MassetStructs.Basset",
        name: "bAsset",
        type: "tuple",
      },
    ],
    payable: false,
    stateMutability: "view",
    type: "function",
  },
  {
    constant: true,
    inputs: [
      {
        internalType: "address",
        name: "_bAsset",
        type: "address",
      },
    ],
    name: "getBassetIntegrator",
    outputs: [
      {
        internalType: "address",
        name: "integrator",
        type: "address",
      },
    ],
    payable: false,
    stateMutability: "view",
    type: "function",
  },
  {
    constant: true,
    inputs: [],
    name: "getBassets",
    outputs: [
      {
        components: [
          {
            internalType: "address",
            name: "addr",
            type: "address",
          },
          {
            internalType: "enum MassetStructs.BassetStatus",
            name: "status",
            type: "uint8",
          },
          {
            internalType: "bool",
            name: "isTransferFeeCharged",
            type: "bool",
          },
          {
            internalType: "uint256",
            name: "ratio",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "maxWeight",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "vaultBalance",
            type: "uint256",
          },
        ],
        internalType: "struct MassetStructs.Basset[]",
        name: "bAssets",
        type: "tuple[]",
      },
      {
        internalType: "uint256",
        name: "len",
        type: "uint256",
      },
    ],
    payable: false,
    stateMutability: "view",
    type: "function",
  },
  {
    constant: false,
    inputs: [
      {
        internalType: "address",
        name: "_bAsset",
        type: "address",
      },
      {
        internalType: "bool",
        name: "_belowPeg",
        type: "bool",
      },
    ],
    name: "handlePegLoss",
    outputs: [
      {
        internalType: "bool",
        name: "alreadyActioned",
        type: "bool",
      },
    ],
    payable: false,
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    constant: false,
    inputs: [
      {
        internalType: "uint8",
        name: "_bAssetIndex",
        type: "uint8",
      },
      {
        internalType: "address",
        name: "",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "_increaseAmount",
        type: "uint256",
      },
    ],
    name: "increaseVaultBalance",
    outputs: [],
    payable: false,
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    constant: false,
    inputs: [
      {
        internalType: "uint8[]",
        name: "_bAssetIndices",
        type: "uint8[]",
      },
      {
        internalType: "address[]",
        name: "",
        type: "address[]",
      },
      {
        internalType: "uint256[]",
        name: "_increaseAmount",
        type: "uint256[]",
      },
    ],
    name: "increaseVaultBalances",
    outputs: [],
    payable: false,
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    constant: false,
    inputs: [
      {
        internalType: "address",
        name: "_nexus",
        type: "address",
      },
      {
        internalType: "address",
        name: "_mAsset",
        type: "address",
      },
      {
        internalType: "address[]",
        name: "_bAssets",
        type: "address[]",
      },
      {
        internalType: "address[]",
        name: "_integrators",
        type: "address[]",
      },
      {
        internalType: "uint256[]",
        name: "_weights",
        type: "uint256[]",
      },
      {
        internalType: "bool[]",
        name: "_hasTransferFees",
        type: "bool[]",
      },
    ],
    name: "initialize",
    outputs: [],
    payable: false,
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    constant: true,
    inputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    name: "integrations",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    payable: false,
    stateMutability: "view",
    type: "function",
  },
  {
    constant: true,
    inputs: [],
    name: "mAsset",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    payable: false,
    stateMutability: "view",
    type: "function",
  },
  {
    constant: false,
    inputs: [
      {
        internalType: "address",
        name: "_bAsset",
        type: "address",
      },
    ],
    name: "negateIsolation",
    outputs: [],
    payable: false,
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    constant: true,
    inputs: [],
    name: "nexus",
    outputs: [
      {
        internalType: "contract INexus",
        name: "",
        type: "address",
      },
    ],
    payable: false,
    stateMutability: "view",
    type: "function",
  },
  {
    constant: false,
    inputs: [],
    name: "pause",
    outputs: [],
    payable: false,
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    constant: true,
    inputs: [],
    name: "paused",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
    payable: false,
    stateMutability: "view",
    type: "function",
  },
  {
    constant: false,
    inputs: [
      {
        internalType: "address",
        name: "_bAsset",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
    name: "prepareForgeBasset",
    outputs: [
      {
        internalType: "bool",
        name: "isValid",
        type: "bool",
      },
      {
        components: [
          {
            components: [
              {
                internalType: "address",
                name: "addr",
                type: "address",
              },
              {
                internalType: "enum MassetStructs.BassetStatus",
                name: "status",
                type: "uint8",
              },
              {
                internalType: "bool",
                name: "isTransferFeeCharged",
                type: "bool",
              },
              {
                internalType: "uint256",
                name: "ratio",
                type: "uint256",
              },
              {
                internalType: "uint256",
                name: "maxWeight",
                type: "uint256",
              },
              {
                internalType: "uint256",
                name: "vaultBalance",
                type: "uint256",
              },
            ],
            internalType: "struct MassetStructs.Basset",
            name: "bAsset",
            type: "tuple",
          },
          {
            internalType: "address",
            name: "integrator",
            type: "address",
          },
          {
            internalType: "uint8",
            name: "index",
            type: "uint8",
          },
        ],
        internalType: "struct MassetStructs.BassetDetails",
        name: "bInfo",
        type: "tuple",
      },
    ],
    payable: false,
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    constant: false,
    inputs: [
      {
        internalType: "address[]",
        name: "_bAssets",
        type: "address[]",
      },
      {
        internalType: "uint256[]",
        name: "",
        type: "uint256[]",
      },
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
    name: "prepareForgeBassets",
    outputs: [
      {
        components: [
          {
            internalType: "bool",
            name: "isValid",
            type: "bool",
          },
          {
            components: [
              {
                internalType: "address",
                name: "addr",
                type: "address",
              },
              {
                internalType: "enum MassetStructs.BassetStatus",
                name: "status",
                type: "uint8",
              },
              {
                internalType: "bool",
                name: "isTransferFeeCharged",
                type: "bool",
              },
              {
                internalType: "uint256",
                name: "ratio",
                type: "uint256",
              },
              {
                internalType: "uint256",
                name: "maxWeight",
                type: "uint256",
              },
              {
                internalType: "uint256",
                name: "vaultBalance",
                type: "uint256",
              },
            ],
            internalType: "struct MassetStructs.Basset[]",
            name: "bAssets",
            type: "tuple[]",
          },
          {
            internalType: "address[]",
            name: "integrators",
            type: "address[]",
          },
          {
            internalType: "uint8[]",
            name: "indexes",
            type: "uint8[]",
          },
        ],
        internalType: "struct MassetStructs.ForgePropsMulti",
        name: "props",
        type: "tuple",
      },
    ],
    payable: false,
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    constant: true,
    inputs: [],
    name: "prepareRedeemMulti",
    outputs: [
      {
        components: [
          {
            internalType: "uint256",
            name: "colRatio",
            type: "uint256",
          },
          {
            components: [
              {
                internalType: "address",
                name: "addr",
                type: "address",
              },
              {
                internalType: "enum MassetStructs.BassetStatus",
                name: "status",
                type: "uint8",
              },
              {
                internalType: "bool",
                name: "isTransferFeeCharged",
                type: "bool",
              },
              {
                internalType: "uint256",
                name: "ratio",
                type: "uint256",
              },
              {
                internalType: "uint256",
                name: "maxWeight",
                type: "uint256",
              },
              {
                internalType: "uint256",
                name: "vaultBalance",
                type: "uint256",
              },
            ],
            internalType: "struct MassetStructs.Basset[]",
            name: "bAssets",
            type: "tuple[]",
          },
          {
            internalType: "address[]",
            name: "integrators",
            type: "address[]",
          },
          {
            internalType: "uint8[]",
            name: "indexes",
            type: "uint8[]",
          },
        ],
        internalType: "struct MassetStructs.RedeemPropsMulti",
        name: "props",
        type: "tuple",
      },
    ],
    payable: false,
    stateMutability: "view",
    type: "function",
  },
  {
    constant: true,
    inputs: [
      {
        internalType: "address",
        name: "_input",
        type: "address",
      },
      {
        internalType: "address",
        name: "_output",
        type: "address",
      },
      {
        internalType: "bool",
        name: "_isMint",
        type: "bool",
      },
    ],
    name: "prepareSwapBassets",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
      {
        internalType: "string",
        name: "",
        type: "string",
      },
      {
        components: [
          {
            components: [
              {
                internalType: "address",
                name: "addr",
                type: "address",
              },
              {
                internalType: "enum MassetStructs.BassetStatus",
                name: "status",
                type: "uint8",
              },
              {
                internalType: "bool",
                name: "isTransferFeeCharged",
                type: "bool",
              },
              {
                internalType: "uint256",
                name: "ratio",
                type: "uint256",
              },
              {
                internalType: "uint256",
                name: "maxWeight",
                type: "uint256",
              },
              {
                internalType: "uint256",
                name: "vaultBalance",
                type: "uint256",
              },
            ],
            internalType: "struct MassetStructs.Basset",
            name: "bAsset",
            type: "tuple",
          },
          {
            internalType: "address",
            name: "integrator",
            type: "address",
          },
          {
            internalType: "uint8",
            name: "index",
            type: "uint8",
          },
        ],
        internalType: "struct MassetStructs.BassetDetails",
        name: "",
        type: "tuple",
      },
      {
        components: [
          {
            components: [
              {
                internalType: "address",
                name: "addr",
                type: "address",
              },
              {
                internalType: "enum MassetStructs.BassetStatus",
                name: "status",
                type: "uint8",
              },
              {
                internalType: "bool",
                name: "isTransferFeeCharged",
                type: "bool",
              },
              {
                internalType: "uint256",
                name: "ratio",
                type: "uint256",
              },
              {
                internalType: "uint256",
                name: "maxWeight",
                type: "uint256",
              },
              {
                internalType: "uint256",
                name: "vaultBalance",
                type: "uint256",
              },
            ],
            internalType: "struct MassetStructs.Basset",
            name: "bAsset",
            type: "tuple",
          },
          {
            internalType: "address",
            name: "integrator",
            type: "address",
          },
          {
            internalType: "uint8",
            name: "index",
            type: "uint8",
          },
        ],
        internalType: "struct MassetStructs.BassetDetails",
        name: "",
        type: "tuple",
      },
    ],
    payable: false,
    stateMutability: "view",
    type: "function",
  },
  {
    constant: false,
    inputs: [
      {
        internalType: "address",
        name: "_assetToRemove",
        type: "address",
      },
    ],
    name: "removeBasset",
    outputs: [],
    payable: false,
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    constant: false,
    inputs: [
      {
        internalType: "address[]",
        name: "_bAssets",
        type: "address[]",
      },
      {
        internalType: "uint256[]",
        name: "_weights",
        type: "uint256[]",
      },
    ],
    name: "setBasketWeights",
    outputs: [],
    payable: false,
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    constant: false,
    inputs: [
      {
        internalType: "address",
        name: "_bAsset",
        type: "address",
      },
      {
        internalType: "bool",
        name: "_flag",
        type: "bool",
      },
    ],
    name: "setTransferFeesFlag",
    outputs: [],
    payable: false,
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    constant: false,
    inputs: [],
    name: "unpause",
    outputs: [],
    payable: false,
    stateMutability: "nonpayable",
    type: "function",
  },
];

const SaveAbi = [
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "owner",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "spender",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "value",
        type: "uint256",
      },
    ],
    name: "Approval",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "bool",
        name: "automationEnabled",
        type: "bool",
      },
    ],
    name: "AutomaticInterestCollectionSwitched",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "address",
        name: "connector",
        type: "address",
      },
    ],
    name: "ConnectorUpdated",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "redeemer",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "creditsRedeemed",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "savingsCredited",
        type: "uint256",
      },
    ],
    name: "CreditsRedeemed",
    type: "event",
  },
  { anonymous: false, inputs: [], name: "EmergencyUpdate", type: "event" },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "uint256",
        name: "newExchangeRate",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "interestCollected",
        type: "uint256",
      },
    ],
    name: "ExchangeRateUpdated",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "uint256",
        name: "fraction",
        type: "uint256",
      },
    ],
    name: "FractionUpdated",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "uint256",
        name: "oldBalance",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "newBalance",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "interestDetected",
        type: "uint256",
      },
    ],
    name: "Poked",
    type: "event",
  },
  { anonymous: false, inputs: [], name: "PokedRaw", type: "event" },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "address",
        name: "poker",
        type: "address",
      },
    ],
    name: "PokerUpdated",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "saver",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "savingsDeposited",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "creditsIssued",
        type: "uint256",
      },
    ],
    name: "SavingsDeposited",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      { indexed: true, internalType: "address", name: "from", type: "address" },
      { indexed: true, internalType: "address", name: "to", type: "address" },
      {
        indexed: false,
        internalType: "uint256",
        name: "value",
        type: "uint256",
      },
    ],
    name: "Transfer",
    type: "event",
  },
  {
    constant: true,
    inputs: [
      { internalType: "address", name: "owner", type: "address" },
      { internalType: "address", name: "spender", type: "address" },
    ],
    name: "allowance",
    outputs: [{ internalType: "uint256", name: "", type: "uint256" }],
    payable: false,
    stateMutability: "view",
    type: "function",
  },
  {
    constant: false,
    inputs: [
      { internalType: "address", name: "spender", type: "address" },
      { internalType: "uint256", name: "amount", type: "uint256" },
    ],
    name: "approve",
    outputs: [{ internalType: "bool", name: "", type: "bool" }],
    payable: false,
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    constant: false,
    inputs: [{ internalType: "bool", name: "_enabled", type: "bool" }],
    name: "automateInterestCollectionFlag",
    outputs: [],
    payable: false,
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    constant: true,
    inputs: [{ internalType: "address", name: "account", type: "address" }],
    name: "balanceOf",
    outputs: [{ internalType: "uint256", name: "", type: "uint256" }],
    payable: false,
    stateMutability: "view",
    type: "function",
  },
  {
    constant: true,
    inputs: [{ internalType: "address", name: "_user", type: "address" }],
    name: "balanceOfUnderlying",
    outputs: [{ internalType: "uint256", name: "balance", type: "uint256" }],
    payable: false,
    stateMutability: "view",
    type: "function",
  },
  {
    constant: true,
    inputs: [],
    name: "connector",
    outputs: [
      { internalType: "contract IConnector", name: "", type: "address" },
    ],
    payable: false,
    stateMutability: "view",
    type: "function",
  },
  {
    constant: true,
    inputs: [{ internalType: "address", name: "_user", type: "address" }],
    name: "creditBalances",
    outputs: [{ internalType: "uint256", name: "", type: "uint256" }],
    payable: false,
    stateMutability: "view",
    type: "function",
  },
  {
    constant: true,
    inputs: [{ internalType: "uint256", name: "_credits", type: "uint256" }],
    name: "creditsToUnderlying",
    outputs: [{ internalType: "uint256", name: "amount", type: "uint256" }],
    payable: false,
    stateMutability: "view",
    type: "function",
  },
  {
    constant: true,
    inputs: [],
    name: "decimals",
    outputs: [{ internalType: "uint8", name: "", type: "uint8" }],
    payable: false,
    stateMutability: "view",
    type: "function",
  },
  {
    constant: false,
    inputs: [
      { internalType: "address", name: "spender", type: "address" },
      { internalType: "uint256", name: "subtractedValue", type: "uint256" },
    ],
    name: "decreaseAllowance",
    outputs: [{ internalType: "bool", name: "", type: "bool" }],
    payable: false,
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    constant: false,
    inputs: [{ internalType: "uint256", name: "_amount", type: "uint256" }],
    name: "depositInterest",
    outputs: [],
    payable: false,
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    constant: false,
    inputs: [
      { internalType: "uint256", name: "_underlying", type: "uint256" },
      { internalType: "address", name: "_beneficiary", type: "address" },
    ],
    name: "depositSavings",
    outputs: [
      { internalType: "uint256", name: "creditsIssued", type: "uint256" },
    ],
    payable: false,
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    constant: false,
    inputs: [{ internalType: "uint256", name: "_underlying", type: "uint256" }],
    name: "depositSavings",
    outputs: [
      { internalType: "uint256", name: "creditsIssued", type: "uint256" },
    ],
    payable: false,
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    constant: false,
    inputs: [
      { internalType: "uint256", name: "_withdrawAmount", type: "uint256" },
    ],
    name: "emergencyWithdraw",
    outputs: [],
    payable: false,
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    constant: true,
    inputs: [],
    name: "exchangeRate",
    outputs: [{ internalType: "uint256", name: "", type: "uint256" }],
    payable: false,
    stateMutability: "view",
    type: "function",
  },
  {
    constant: true,
    inputs: [],
    name: "fraction",
    outputs: [{ internalType: "uint256", name: "", type: "uint256" }],
    payable: false,
    stateMutability: "view",
    type: "function",
  },
  {
    constant: false,
    inputs: [
      { internalType: "address", name: "spender", type: "address" },
      { internalType: "uint256", name: "addedValue", type: "uint256" },
    ],
    name: "increaseAllowance",
    outputs: [{ internalType: "bool", name: "", type: "bool" }],
    payable: false,
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    constant: false,
    inputs: [
      { internalType: "address", name: "_poker", type: "address" },
      { internalType: "string", name: "_nameArg", type: "string" },
      { internalType: "string", name: "_symbolArg", type: "string" },
    ],
    name: "initialize",
    outputs: [],
    payable: false,
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    constant: true,
    inputs: [],
    name: "lastBalance",
    outputs: [{ internalType: "uint256", name: "", type: "uint256" }],
    payable: false,
    stateMutability: "view",
    type: "function",
  },
  {
    constant: true,
    inputs: [],
    name: "lastPoke",
    outputs: [{ internalType: "uint256", name: "", type: "uint256" }],
    payable: false,
    stateMutability: "view",
    type: "function",
  },
  {
    constant: true,
    inputs: [],
    name: "name",
    outputs: [{ internalType: "string", name: "", type: "string" }],
    payable: false,
    stateMutability: "view",
    type: "function",
  },
  {
    constant: true,
    inputs: [],
    name: "nexus",
    outputs: [{ internalType: "contract INexus", name: "", type: "address" }],
    payable: false,
    stateMutability: "view",
    type: "function",
  },
  {
    constant: false,
    inputs: [],
    name: "poke",
    outputs: [],
    payable: false,
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    constant: true,
    inputs: [],
    name: "poker",
    outputs: [{ internalType: "address", name: "", type: "address" }],
    payable: false,
    stateMutability: "view",
    type: "function",
  },
  {
    constant: false,
    inputs: [
      { internalType: "uint256", name: "_underlying", type: "uint256" },
      { internalType: "address", name: "_beneficiary", type: "address" },
    ],
    name: "preDeposit",
    outputs: [
      { internalType: "uint256", name: "creditsIssued", type: "uint256" },
    ],
    payable: false,
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    constant: false,
    inputs: [{ internalType: "uint256", name: "_credits", type: "uint256" }],
    name: "redeem",
    outputs: [
      { internalType: "uint256", name: "massetReturned", type: "uint256" },
    ],
    payable: false,
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    constant: false,
    inputs: [{ internalType: "uint256", name: "_credits", type: "uint256" }],
    name: "redeemCredits",
    outputs: [
      { internalType: "uint256", name: "massetReturned", type: "uint256" },
    ],
    payable: false,
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    constant: false,
    inputs: [{ internalType: "uint256", name: "_underlying", type: "uint256" }],
    name: "redeemUnderlying",
    outputs: [
      { internalType: "uint256", name: "creditsBurned", type: "uint256" },
    ],
    payable: false,
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    constant: false,
    inputs: [
      { internalType: "address", name: "_newConnector", type: "address" },
    ],
    name: "setConnector",
    outputs: [],
    payable: false,
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    constant: false,
    inputs: [{ internalType: "uint256", name: "_fraction", type: "uint256" }],
    name: "setFraction",
    outputs: [],
    payable: false,
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    constant: false,
    inputs: [{ internalType: "address", name: "_newPoker", type: "address" }],
    name: "setPoker",
    outputs: [],
    payable: false,
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    constant: true,
    inputs: [],
    name: "symbol",
    outputs: [{ internalType: "string", name: "", type: "string" }],
    payable: false,
    stateMutability: "view",
    type: "function",
  },
  {
    constant: true,
    inputs: [],
    name: "totalSupply",
    outputs: [{ internalType: "uint256", name: "", type: "uint256" }],
    payable: false,
    stateMutability: "view",
    type: "function",
  },
  {
    constant: false,
    inputs: [
      { internalType: "address", name: "recipient", type: "address" },
      { internalType: "uint256", name: "amount", type: "uint256" },
    ],
    name: "transfer",
    outputs: [{ internalType: "bool", name: "", type: "bool" }],
    payable: false,
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    constant: false,
    inputs: [
      { internalType: "address", name: "sender", type: "address" },
      { internalType: "address", name: "recipient", type: "address" },
      { internalType: "uint256", name: "amount", type: "uint256" },
    ],
    name: "transferFrom",
    outputs: [{ internalType: "bool", name: "", type: "bool" }],
    payable: false,
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    constant: true,
    inputs: [],
    name: "underlying",
    outputs: [{ internalType: "contract IERC20", name: "", type: "address" }],
    payable: false,
    stateMutability: "view",
    type: "function",
  },
  {
    constant: true,
    inputs: [{ internalType: "uint256", name: "_underlying", type: "uint256" }],
    name: "underlyingToCredits",
    outputs: [{ internalType: "uint256", name: "credits", type: "uint256" }],
    payable: false,
    stateMutability: "view",
    type: "function",
  },
];
