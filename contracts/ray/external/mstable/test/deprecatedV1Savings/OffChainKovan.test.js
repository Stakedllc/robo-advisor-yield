// FOR SAVINGS V1 - DEPRECATED

const { ethers } = require("ethers");

require('dotenv').config()

const ether = (n) => {
  return ethers.utils.parseEther(n.toString());
};

const tokens = (n) => ether(n);

const fromWei = (n) => {
  return ethers.utils.formatEther(n);
};


let result;

const init = async () => {

  const provider = ethers.getDefaultProvider("kovan", {
    infura: process.env.INFURA_KEY_KOVAN,
  });
  const options = { gasLimit: 1000000 };
  // console.log(provider)
  const signer = new ethers.Wallet(
    process.env.PRIVATE_KEY
  );


  const deployer = await signer.connect(provider);

  console.log("Deployer Address", deployer.address); // 0x3Cc7245E020C98d289908730B8Cf6Ad279b77A12

  const helperAddress = "0x790d4f6ce913278e35192f3cf91b90e53657222b";

  const saveAddress = "0x54Ac0bdf4292F7565Af13C9FBEf214eEEB2d0F87";
  const proxy = "0x70605bdd16e52c86fc7031446d995cf5c7e1b0e7";
  
  const mAsset = "0x4534042F31acDB0c84AB04365d529C088f35359A"; // kovan mAsset
  const mUSD = "0x70605Bdd16e52c86FC7031446D995Cf5c7E1b0e7";

  const storageRayMockUp = "0x948d3D9900bC9C428F5c69dccf6b7Ea24fb6b810";

  const tusdKovan = "0xe22da380ee6B445bb8273C81944ADEB6E8450422";
  
  const DAI = '0x4f96fe3b7a6cf9725f59d353f723c1bdb64ca6aa'
  const USDC = '0xb7a4f3e9097c08da09517b5ab877f7a917224ede'
  const TUSD = '0x1c4a937d171752e1313d70fb16ae2ea02f86303e'
  const USDT = "0x13512979ade267ab5100878e2e0f485b568328a4";
 const opportunityAddress = '0x53B63C6a5da9269921D86d94D911A72a5d25e3F7'
 
  
  const opportunityContract = new ethers.Contract(
    opportunityAddress,
    OpportunityAbi,
    provider
  );

  const helperContract = new ethers.Contract(
    helperAddress,
    HelperAbi,
    provider
  );
  const helperSigned = helperContract.connect(deployer);

  const mAssetContract = new ethers.Contract(mAsset, MassetAbi, provider);
  const mAssetSigned = mAssetContract.connect(deployer);

  const proxyContract = new ethers.Contract(proxy, ProxyAbi, provider);
  const proxySigned = proxyContract.connect(deployer);

  const daiContract = new ethers.Contract(DAI, ERC20Abi, provider);
  const DAISigned = daiContract.connect(deployer);

  const massetProxyContract = new ethers.Contract(proxy, MassetAbi, provider);
  const massetProxySigned = massetProxyContract.connect(deployer);
  
  const saveContract = new ethers.Contract(saveAddress, SaveAbi, provider);
  const saveSigned = saveContract.connect(deployer);



  const mUSDContract = new ethers.Contract(mUSD, ERC20Abi, provider);
  const mUSDSigned = mUSDContract.connect(deployer);
  
  const opportunity = opportunityContract.connect(deployer);

  let result;
  let receipt;


  // check masset address
  result = await opportunity.markets(DAI);

  console.log(result, "proxy");

  result = await mAssetSigned.getBasketManager();

  
  
  console.log(result, "basket contract");

  result = await massetProxySigned.getBasketManager();

  const basketContract = new ethers.Contract(result, BasketManagerAbi, provider);
  const basketSigned = basketContract.connect(deployer);
  
  console.log(result, "basket contract");

  // APPROVE usdT for mAsset
  // result = await usdTSigned.approve(proxy,tokens(9990), options)
  // console.log(result)

  result = await massetProxySigned.balanceOf(
    "0x519f11CDD52bbbDC865c72A6549EA67429C22991"
  );
  console.log(result.toString(),'opporunity manager mUSD balance');


  

 
  try {

  

  const getSupply = async(bAsset) => {
    saveBalance = await helperSigned.getSaveBalance(saveAddress,opportunityAddress)
    console.log(saveBalance.toString(), 'saver balance in mUSD wei')
  
    result = await helperSigned.getRedeemValidity(mUSD,saveBalance,bAsset);
    console.log(result.output.toString(), `actual value that will be credited for asset ${bAsset}`)
    console.log(result.bassetQuantityArg.toString(), `input argument for redeeming, correspond to the supplied amount independently from which asset we deposited`)

    return result.bassetQuantityArg.toString() // or result.output.toString() depending which one should be returned for the bot

  }

  // credits can be redeemed fot any assets, independetly from which asset we deposited. When calling getSupply we have to rememeber that 
  // this is the possible supply but if we redeem from one of them it will be affected.
  await getSupply(DAI)
  await getSupply(TUSD)
  await getSupply(USDC)
  await getSupply(USDT)


  const getDemand = async() => {
    result = await helperSigned.getSaveBalance(saveAddress,opportunityAddress)
    console.log(result.toString(), 'credits balance in mUSD wei')
    result = await helperSigned.getSaveRedeemInput(saveAddress, result);
    console.log(result.toString(), 'credits')
  }

  await getDemand()


  const getLiquidity = async(bAsset) => {
 
     
    result = await basketSigned.getBasset(bAsset)
    console.log(result.vaultBalance.toString(), `${bAsset} total liquidity`)


    return result.vaultBalance.toString()
    
  }
    
  await getLiquidity(DAI)
  await getLiquidity(USDC)
  await getLiquidity(TUSD)
  await getLiquidity(USDT)
    
  } catch (err) {
    console.log(err);
  }






 };

init();



const OpportunityAbi = [
  {
    "payable": true,
    "stateMutability": "payable",
    "type": "fallback"
  },
  {
    "constant": false,
    "inputs": [
      {
        "internalType": "address[]",
        "name": "principalTokens",
        "type": "address[]"
      },
      {
        "internalType": "address[]",
        "name": "otherContracts",
        "type": "address[]"
      }
    ],
    "name": "addPrincipalTokens",
    "outputs": [],
    "payable": false,
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "constant": false,
    "inputs": [
      {
        "internalType": "address",
        "name": "token",
        "type": "address"
      }
    ],
    "name": "approveEach",
    "outputs": [],
    "payable": false,
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "constant": false,
    "inputs": [
      {
        "internalType": "address",
        "name": "token",
        "type": "address"
      }
    ],
    "name": "approveOnce",
    "outputs": [],
    "payable": false,
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "constant": true,
    "inputs": [
      {
        "internalType": "address",
        "name": "token",
        "type": "address"
      }
    ],
    "name": "getBalance",
    "outputs": [
      {
        "internalType": "uint256",
        "name": "",
        "type": "uint256"
      }
    ],
    "payable": false,
    "stateMutability": "view",
    "type": "function"
  },
  {
    "constant": true,
    "inputs": [],
    "name": "getRate",
    "outputs": [
      {
        "internalType": "uint256",
        "name": "",
        "type": "uint256"
      }
    ],
    "payable": false,
    "stateMutability": "view",
    "type": "function"
  },
  {
    "constant": true,
    "inputs": [
      {
        "internalType": "address",
        "name": "token",
        "type": "address"
      }
    ],
    "name": "getSupply",
    "outputs": [
      {
        "internalType": "bool",
        "name": "",
        "type": "bool"
      },
      {
        "internalType": "uint256",
        "name": "",
        "type": "uint256"
      },
      {
        "internalType": "uint256",
        "name": "",
        "type": "uint256"
      }
    ],
    "payable": false,
    "stateMutability": "view",
    "type": "function"
  },
  {
    "constant": true,
    "inputs": [],
    "name": "helper",
    "outputs": [
      {
        "internalType": "contract IMStableHelper",
        "name": "",
        "type": "address"
      }
    ],
    "payable": false,
    "stateMutability": "view",
    "type": "function"
  },
  {
    "constant": false,
    "inputs": [
      {
        "internalType": "address",
        "name": "storage_contract",
        "type": "address"
      },
      {
        "internalType": "address[]",
        "name": "principalToken",
        "type": "address[]"
      },
      {
        "internalType": "address[]",
        "name": "otherToken",
        "type": "address[]"
      },
      {
        "internalType": "address",
        "name": "_savingsContract",
        "type": "address"
      },
      {
        "internalType": "address",
        "name": "_mStableHelper",
        "type": "address"
      },
      {
        "internalType": "address",
        "name": "_mUSD",
        "type": "address"
      }
    ],
    "name": "initialize",
    "outputs": [],
    "payable": false,
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "constant": true,
    "inputs": [],
    "name": "mUSD",
    "outputs": [
      {
        "internalType": "address",
        "name": "",
        "type": "address"
      }
    ],
    "payable": false,
    "stateMutability": "view",
    "type": "function"
  },
  {
    "constant": true,
    "inputs": [
      {
        "internalType": "address",
        "name": "",
        "type": "address"
      }
    ],
    "name": "markets",
    "outputs": [
      {
        "internalType": "address",
        "name": "",
        "type": "address"
      }
    ],
    "payable": false,
    "stateMutability": "view",
    "type": "function"
  },
  {
    "constant": true,
    "inputs": [],
    "name": "rayStorage",
    "outputs": [
      {
        "internalType": "contract IStorage",
        "name": "",
        "type": "address"
      }
    ],
    "payable": false,
    "stateMutability": "view",
    "type": "function"
  },
  {
    "constant": true,
    "inputs": [],
    "name": "saveAddress",
    "outputs": [
      {
        "internalType": "address",
        "name": "",
        "type": "address"
      }
    ],
    "payable": false,
    "stateMutability": "view",
    "type": "function"
  },
  {
    "constant": true,
    "inputs": [],
    "name": "savingsContract",
    "outputs": [
      {
        "internalType": "contract ISavingsContract",
        "name": "",
        "type": "address"
      }
    ],
    "payable": false,
    "stateMutability": "view",
    "type": "function"
  },
  {
    "constant": false,
    "inputs": [
      {
        "internalType": "address",
        "name": "token",
        "type": "address"
      },
      {
        "internalType": "uint256",
        "name": "amount",
        "type": "uint256"
      },
      {
        "internalType": "bool",
        "name": "isERC20",
        "type": "bool"
      }
    ],
    "name": "supply",
    "outputs": [],
    "payable": true,
    "stateMutability": "payable",
    "type": "function"
  },
  {
    "constant": false,
    "inputs": [
      {
        "internalType": "address",
        "name": "token",
        "type": "address"
      },
      {
        "internalType": "address",
        "name": "beneficiary",
        "type": "address"
      },
      {
        "internalType": "uint256",
        "name": "amount",
        "type": "uint256"
      },
      {
        "internalType": "bool",
        "name": "isERC20",
        "type": "bool"
      }
    ],
    "name": "withdraw",
    "outputs": [],
    "payable": false,
    "stateMutability": "nonpayable",
    "type": "function"
  }
]

const ProxyAbi = [
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "address",
        name: "previousAdmin",
        type: "address",
      },
      {
        indexed: false,
        internalType: "address",
        name: "newAdmin",
        type: "address",
      },
    ],
    name: "AdminChanged",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "implementation",
        type: "address",
      },
    ],
    name: "Upgraded",
    type: "event",
  },
  { payable: true, stateMutability: "payable", type: "fallback" },
  {
    constant: false,
    inputs: [],
    name: "admin",
    outputs: [{ internalType: "address", name: "", type: "address" }],
    payable: false,
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    constant: false,
    inputs: [{ internalType: "address", name: "newAdmin", type: "address" }],
    name: "changeAdmin",
    outputs: [],
    payable: false,
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    constant: false,
    inputs: [],
    name: "implementation",
    outputs: [{ internalType: "address", name: "", type: "address" }],
    payable: false,
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    constant: false,
    inputs: [
      { internalType: "address", name: "_logic", type: "address" },
      { internalType: "address", name: "_admin", type: "address" },
      { internalType: "bytes", name: "_data", type: "bytes" },
    ],
    name: "initialize",
    outputs: [],
    payable: true,
    stateMutability: "payable",
    type: "function",
  },
  {
    constant: false,
    inputs: [
      { internalType: "address", name: "_logic", type: "address" },
      { internalType: "bytes", name: "_data", type: "bytes" },
    ],
    name: "initialize",
    outputs: [],
    payable: true,
    stateMutability: "payable",
    type: "function",
  },
  {
    constant: false,
    inputs: [
      { internalType: "address", name: "newImplementation", type: "address" },
    ],
    name: "upgradeTo",
    outputs: [],
    payable: false,
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    constant: false,
    inputs: [
      { internalType: "address", name: "newImplementation", type: "address" },
      { internalType: "bytes", name: "data", type: "bytes" },
    ],
    name: "upgradeToAndCall",
    outputs: [],
    payable: true,
    stateMutability: "payable",
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

const MassetAbi = [
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
        internalType: "address",
        name: "forgeValidator",
        type: "address",
      },
    ],
    name: "ForgeValidatorChanged",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "minter",
        type: "address",
      },
      {
        indexed: false,
        internalType: "address",
        name: "recipient",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "mAssetQuantity",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "address",
        name: "bAsset",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "bAssetQuantity",
        type: "uint256",
      },
    ],
    name: "Minted",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "minter",
        type: "address",
      },
      {
        indexed: false,
        internalType: "address",
        name: "recipient",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "mAssetQuantity",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "address[]",
        name: "bAssets",
        type: "address[]",
      },
      {
        indexed: false,
        internalType: "uint256[]",
        name: "bAssetQuantities",
        type: "uint256[]",
      },
    ],
    name: "MintedMulti",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "payer",
        type: "address",
      },
      {
        indexed: false,
        internalType: "address",
        name: "asset",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "feeQuantity",
        type: "uint256",
      },
    ],
    name: "PaidFee",
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
        internalType: "address",
        name: "recipient",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "mAssetQuantity",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "address[]",
        name: "bAssets",
        type: "address[]",
      },
      {
        indexed: false,
        internalType: "uint256[]",
        name: "bAssetQuantities",
        type: "uint256[]",
      },
    ],
    name: "Redeemed",
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
        internalType: "address",
        name: "recipient",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "mAssetQuantity",
        type: "uint256",
      },
    ],
    name: "RedeemedMasset",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "uint256",
        name: "fee",
        type: "uint256",
      },
    ],
    name: "RedemptionFeeChanged",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "uint256",
        name: "fee",
        type: "uint256",
      },
    ],
    name: "SwapFeeChanged",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "swapper",
        type: "address",
      },
      {
        indexed: false,
        internalType: "address",
        name: "input",
        type: "address",
      },
      {
        indexed: false,
        internalType: "address",
        name: "output",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "outputAmount",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "address",
        name: "recipient",
        type: "address",
      },
    ],
    name: "Swapped",
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
        name: "amount",
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
        name: "account",
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
    constant: false,
    inputs: [],
    name: "collectInterest",
    outputs: [
      {
        internalType: "uint256",
        name: "totalInterestGained",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "newSupply",
        type: "uint256",
      },
    ],
    payable: false,
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    constant: true,
    inputs: [],
    name: "decimals",
    outputs: [
      {
        internalType: "uint8",
        name: "",
        type: "uint8",
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
        name: "subtractedValue",
        type: "uint256",
      },
    ],
    name: "decreaseAllowance",
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
    inputs: [],
    name: "forgeValidator",
    outputs: [
      {
        internalType: "contract IForgeValidator",
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
    name: "getBasketManager",
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
        name: "_input",
        type: "address",
      },
      {
        internalType: "address",
        name: "_output",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "_quantity",
        type: "uint256",
      },
    ],
    name: "getSwapOutput",
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
        internalType: "uint256",
        name: "output",
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
        name: "addedValue",
        type: "uint256",
      },
    ],
    name: "increaseAllowance",
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
        internalType: "string",
        name: "_nameArg",
        type: "string",
      },
      {
        internalType: "string",
        name: "_symbolArg",
        type: "string",
      },
      {
        internalType: "address",
        name: "_nexus",
        type: "address",
      },
      {
        internalType: "address",
        name: "_forgeValidator",
        type: "address",
      },
      {
        internalType: "address",
        name: "_basketManager",
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
    constant: false,
    inputs: [],
    name: "lockForgeValidator",
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
        internalType: "uint256",
        name: "_bAssetQuantity",
        type: "uint256",
      },
    ],
    name: "mint",
    outputs: [
      {
        internalType: "uint256",
        name: "massetMinted",
        type: "uint256",
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
        name: "_bAssetQuantity",
        type: "uint256[]",
      },
      {
        internalType: "address",
        name: "_recipient",
        type: "address",
      },
    ],
    name: "mintMulti",
    outputs: [
      {
        internalType: "uint256",
        name: "massetMinted",
        type: "uint256",
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
        name: "_bAsset",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "_bAssetQuantity",
        type: "uint256",
      },
      {
        internalType: "address",
        name: "_recipient",
        type: "address",
      },
    ],
    name: "mintTo",
    outputs: [
      {
        internalType: "uint256",
        name: "massetMinted",
        type: "uint256",
      },
    ],
    payable: false,
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    constant: true,
    inputs: [],
    name: "name",
    outputs: [
      {
        internalType: "string",
        name: "",
        type: "string",
      },
    ],
    payable: false,
    stateMutability: "view",
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
    inputs: [
      {
        internalType: "address",
        name: "_bAsset",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "_bAssetQuantity",
        type: "uint256",
      },
    ],
    name: "redeem",
    outputs: [
      {
        internalType: "uint256",
        name: "massetRedeemed",
        type: "uint256",
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
        internalType: "uint256",
        name: "_mAssetQuantity",
        type: "uint256",
      },
      {
        internalType: "address",
        name: "_recipient",
        type: "address",
      },
    ],
    name: "redeemMasset",
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
        name: "_bAssetQuantities",
        type: "uint256[]",
      },
      {
        internalType: "address",
        name: "_recipient",
        type: "address",
      },
    ],
    name: "redeemMulti",
    outputs: [
      {
        internalType: "uint256",
        name: "massetRedeemed",
        type: "uint256",
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
        name: "_bAsset",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "_bAssetQuantity",
        type: "uint256",
      },
      {
        internalType: "address",
        name: "_recipient",
        type: "address",
      },
    ],
    name: "redeemTo",
    outputs: [
      {
        internalType: "uint256",
        name: "massetRedeemed",
        type: "uint256",
      },
    ],
    payable: false,
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    constant: true,
    inputs: [],
    name: "redemptionFee",
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
        internalType: "uint256",
        name: "_redemptionFee",
        type: "uint256",
      },
    ],
    name: "setRedemptionFee",
    outputs: [],
    payable: false,
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    constant: false,
    inputs: [
      {
        internalType: "uint256",
        name: "_swapFee",
        type: "uint256",
      },
    ],
    name: "setSwapFee",
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
        name: "_input",
        type: "address",
      },
      {
        internalType: "address",
        name: "_output",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "_quantity",
        type: "uint256",
      },
      {
        internalType: "address",
        name: "_recipient",
        type: "address",
      },
    ],
    name: "swap",
    outputs: [
      {
        internalType: "uint256",
        name: "output",
        type: "uint256",
      },
    ],
    payable: false,
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    constant: true,
    inputs: [],
    name: "swapFee",
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
    name: "symbol",
    outputs: [
      {
        internalType: "string",
        name: "",
        type: "string",
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
        name: "recipient",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "amount",
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
        name: "sender",
        type: "address",
      },
      {
        internalType: "address",
        name: "recipient",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "amount",
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
  {
    constant: false,
    inputs: [
      {
        internalType: "address",
        name: "_newForgeValidator",
        type: "address",
      },
    ],
    name: "upgradeForgeValidator",
    outputs: [],
    payable: false,
    stateMutability: "nonpayable",
    type: "function",
  },
];

const USDTAbi = [
  {
    constant: true,
    inputs: [],
    name: "name",
    outputs: [{ name: "", type: "string" }],
    payable: false,
    stateMutability: "view",
    type: "function",
  },
  {
    constant: false,
    inputs: [
      { name: "spender", type: "address" },
      { name: "value", type: "uint256" },
    ],
    name: "approve",
    outputs: [{ name: "", type: "bool" }],
    payable: false,
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    constant: true,
    inputs: [],
    name: "totalSupply",
    outputs: [{ name: "", type: "uint256" }],
    payable: false,
    stateMutability: "view",
    type: "function",
  },
  {
    constant: false,
    inputs: [
      { name: "sender", type: "address" },
      { name: "recipient", type: "address" },
      { name: "amount", type: "uint256" },
    ],
    name: "transferFrom",
    outputs: [{ name: "", type: "bool" }],
    payable: false,
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    constant: true,
    inputs: [],
    name: "decimals",
    outputs: [{ name: "", type: "uint256" }],
    payable: false,
    stateMutability: "view",
    type: "function",
  },
  {
    constant: false,
    inputs: [
      { name: "spender", type: "address" },
      { name: "addedValue", type: "uint256" },
    ],
    name: "increaseAllowance",
    outputs: [{ name: "", type: "bool" }],
    payable: false,
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    constant: true,
    inputs: [{ name: "account", type: "address" }],
    name: "balanceOf",
    outputs: [{ name: "", type: "uint256" }],
    payable: false,
    stateMutability: "view",
    type: "function",
  },
  {
    constant: true,
    inputs: [],
    name: "symbol",
    outputs: [{ name: "", type: "string" }],
    payable: false,
    stateMutability: "view",
    type: "function",
  },
  {
    constant: false,
    inputs: [{ name: "value", type: "uint256" }],
    name: "mint",
    outputs: [{ name: "", type: "bool" }],
    payable: false,
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    constant: false,
    inputs: [
      { name: "spender", type: "address" },
      { name: "subtractedValue", type: "uint256" },
    ],
    name: "decreaseAllowance",
    outputs: [{ name: "", type: "bool" }],
    payable: false,
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    constant: false,
    inputs: [
      { name: "recipient", type: "address" },
      { name: "amount", type: "uint256" },
    ],
    name: "transfer",
    outputs: [{ name: "", type: "bool" }],
    payable: false,
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    constant: true,
    inputs: [
      { name: "owner", type: "address" },
      { name: "spender", type: "address" },
    ],
    name: "allowance",
    outputs: [{ name: "", type: "uint256" }],
    payable: false,
    stateMutability: "view",
    type: "function",
  },
  {
    anonymous: false,
    inputs: [
      { indexed: true, name: "from", type: "address" },
      { indexed: true, name: "to", type: "address" },
      { indexed: false, name: "value", type: "uint256" },
    ],
    name: "Transfer",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      { indexed: true, name: "owner", type: "address" },
      { indexed: true, name: "spender", type: "address" },
      { indexed: false, name: "value", type: "uint256" },
    ],
    name: "Approval",
    type: "event",
  },
];

const SaveAbi = [
  {
    inputs: [
      {
        internalType: "address",
        name: "_nexus",
        type: "address",
      },
      {
        internalType: "contract IERC20",
        name: "_mUSD",
        type: "address",
      },
    ],
    payable: false,
    stateMutability: "nonpayable",
    type: "constructor",
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
    constant: false,
    inputs: [
      {
        internalType: "bool",
        name: "_enabled",
        type: "bool",
      },
    ],
    name: "automateInterestCollectionFlag",
    outputs: [],
    payable: false,
    stateMutability: "nonpayable",
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
    name: "creditBalances",
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
        internalType: "uint256",
        name: "_amount",
        type: "uint256",
      },
    ],
    name: "depositInterest",
    outputs: [],
    payable: false,
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    constant: false,
    inputs: [
      {
        internalType: "uint256",
        name: "_amount",
        type: "uint256",
      },
    ],
    name: "depositSavings",
    outputs: [
      {
        internalType: "uint256",
        name: "creditsIssued",
        type: "uint256",
      },
    ],
    payable: false,
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    constant: true,
    inputs: [],
    name: "exchangeRate",
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
    inputs: [
      {
        internalType: "uint256",
        name: "_credits",
        type: "uint256",
      },
    ],
    name: "redeem",
    outputs: [
      {
        internalType: "uint256",
        name: "massetReturned",
        type: "uint256",
      },
    ],
    payable: false,
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    constant: true,
    inputs: [],
    name: "totalCredits",
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
    name: "totalSavings",
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

const BasketManagerAbi = [
  {
    "anonymous": false,
    "inputs": [],
    "name": "BasketStatusChanged",
    "type": "event"
  },
  {
    "anonymous": false,
    "inputs": [
      {
        "indexed": false,
        "internalType": "address[]",
        "name": "bAssets",
        "type": "address[]"
      },
      {
        "indexed": false,
        "internalType": "uint256[]",
        "name": "maxWeights",
        "type": "uint256[]"
      }
    ],
    "name": "BasketWeightsUpdated",
    "type": "event"
  },
  {
    "anonymous": false,
    "inputs": [
      {
        "indexed": true,
        "internalType": "address",
        "name": "bAsset",
        "type": "address"
      },
      {
        "indexed": false,
        "internalType": "address",
        "name": "integrator",
        "type": "address"
      }
    ],
    "name": "BassetAdded",
    "type": "event"
  },
  {
    "anonymous": false,
    "inputs": [
      {
        "indexed": true,
        "internalType": "address",
        "name": "bAsset",
        "type": "address"
      }
    ],
    "name": "BassetRemoved",
    "type": "event"
  },
  {
    "anonymous": false,
    "inputs": [
      {
        "indexed": true,
        "internalType": "address",
        "name": "bAsset",
        "type": "address"
      },
      {
        "indexed": false,
        "internalType": "enum MassetStructs.BassetStatus",
        "name": "status",
        "type": "uint8"
      }
    ],
    "name": "BassetStatusChanged",
    "type": "event"
  },
  {
    "anonymous": false,
    "inputs": [
      {
        "indexed": false,
        "internalType": "address",
        "name": "account",
        "type": "address"
      }
    ],
    "name": "Paused",
    "type": "event"
  },
  {
    "anonymous": false,
    "inputs": [
      {
        "indexed": true,
        "internalType": "address",
        "name": "bAsset",
        "type": "address"
      },
      {
        "indexed": false,
        "internalType": "bool",
        "name": "enabled",
        "type": "bool"
      }
    ],
    "name": "TransferFeeEnabled",
    "type": "event"
  },
  {
    "anonymous": false,
    "inputs": [
      {
        "indexed": false,
        "internalType": "address",
        "name": "account",
        "type": "address"
      }
    ],
    "name": "Unpaused",
    "type": "event"
  },
  {
    "constant": false,
    "inputs": [
      {
        "internalType": "address",
        "name": "_bAsset",
        "type": "address"
      },
      {
        "internalType": "address",
        "name": "_integration",
        "type": "address"
      },
      {
        "internalType": "bool",
        "name": "_isTransferFeeCharged",
        "type": "bool"
      }
    ],
    "name": "addBasset",
    "outputs": [
      {
        "internalType": "uint8",
        "name": "index",
        "type": "uint8"
      }
    ],
    "payable": false,
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "constant": true,
    "inputs": [],
    "name": "basket",
    "outputs": [
      {
        "internalType": "uint8",
        "name": "maxBassets",
        "type": "uint8"
      },
      {
        "internalType": "bool",
        "name": "undergoingRecol",
        "type": "bool"
      },
      {
        "internalType": "bool",
        "name": "failed",
        "type": "bool"
      },
      {
        "internalType": "uint256",
        "name": "collateralisationRatio",
        "type": "uint256"
      }
    ],
    "payable": false,
    "stateMutability": "view",
    "type": "function"
  },
  {
    "constant": false,
    "inputs": [],
    "name": "collectInterest",
    "outputs": [
      {
        "internalType": "uint256",
        "name": "interestCollected",
        "type": "uint256"
      },
      {
        "internalType": "uint256[]",
        "name": "gains",
        "type": "uint256[]"
      }
    ],
    "payable": false,
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "constant": false,
    "inputs": [
      {
        "internalType": "uint8",
        "name": "_bAssetIndex",
        "type": "uint8"
      },
      {
        "internalType": "address",
        "name": "",
        "type": "address"
      },
      {
        "internalType": "uint256",
        "name": "_decreaseAmount",
        "type": "uint256"
      }
    ],
    "name": "decreaseVaultBalance",
    "outputs": [],
    "payable": false,
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "constant": false,
    "inputs": [
      {
        "internalType": "uint8[]",
        "name": "_bAssetIndices",
        "type": "uint8[]"
      },
      {
        "internalType": "address[]",
        "name": "",
        "type": "address[]"
      },
      {
        "internalType": "uint256[]",
        "name": "_decreaseAmount",
        "type": "uint256[]"
      }
    ],
    "name": "decreaseVaultBalances",
    "outputs": [],
    "payable": false,
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "constant": false,
    "inputs": [
      {
        "internalType": "address",
        "name": "_bAsset",
        "type": "address"
      }
    ],
    "name": "failBasset",
    "outputs": [],
    "payable": false,
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "constant": true,
    "inputs": [],
    "name": "getBasket",
    "outputs": [
      {
        "components": [
          {
            "components": [
              {
                "internalType": "address",
                "name": "addr",
                "type": "address"
              },
              {
                "internalType": "enum MassetStructs.BassetStatus",
                "name": "status",
                "type": "uint8"
              },
              {
                "internalType": "bool",
                "name": "isTransferFeeCharged",
                "type": "bool"
              },
              {
                "internalType": "uint256",
                "name": "ratio",
                "type": "uint256"
              },
              {
                "internalType": "uint256",
                "name": "maxWeight",
                "type": "uint256"
              },
              {
                "internalType": "uint256",
                "name": "vaultBalance",
                "type": "uint256"
              }
            ],
            "internalType": "struct MassetStructs.Basset[]",
            "name": "bassets",
            "type": "tuple[]"
          },
          {
            "internalType": "uint8",
            "name": "maxBassets",
            "type": "uint8"
          },
          {
            "internalType": "bool",
            "name": "undergoingRecol",
            "type": "bool"
          },
          {
            "internalType": "bool",
            "name": "failed",
            "type": "bool"
          },
          {
            "internalType": "uint256",
            "name": "collateralisationRatio",
            "type": "uint256"
          }
        ],
        "internalType": "struct MassetStructs.Basket",
        "name": "b",
        "type": "tuple"
      }
    ],
    "payable": false,
    "stateMutability": "view",
    "type": "function"
  },
  {
    "constant": true,
    "inputs": [
      {
        "internalType": "address",
        "name": "_bAsset",
        "type": "address"
      }
    ],
    "name": "getBasset",
    "outputs": [
      {
        "components": [
          {
            "internalType": "address",
            "name": "addr",
            "type": "address"
          },
          {
            "internalType": "enum MassetStructs.BassetStatus",
            "name": "status",
            "type": "uint8"
          },
          {
            "internalType": "bool",
            "name": "isTransferFeeCharged",
            "type": "bool"
          },
          {
            "internalType": "uint256",
            "name": "ratio",
            "type": "uint256"
          },
          {
            "internalType": "uint256",
            "name": "maxWeight",
            "type": "uint256"
          },
          {
            "internalType": "uint256",
            "name": "vaultBalance",
            "type": "uint256"
          }
        ],
        "internalType": "struct MassetStructs.Basset",
        "name": "bAsset",
        "type": "tuple"
      }
    ],
    "payable": false,
    "stateMutability": "view",
    "type": "function"
  },
  {
    "constant": true,
    "inputs": [
      {
        "internalType": "address",
        "name": "_bAsset",
        "type": "address"
      }
    ],
    "name": "getBassetIntegrator",
    "outputs": [
      {
        "internalType": "address",
        "name": "integrator",
        "type": "address"
      }
    ],
    "payable": false,
    "stateMutability": "view",
    "type": "function"
  },
  {
    "constant": true,
    "inputs": [],
    "name": "getBassets",
    "outputs": [
      {
        "components": [
          {
            "internalType": "address",
            "name": "addr",
            "type": "address"
          },
          {
            "internalType": "enum MassetStructs.BassetStatus",
            "name": "status",
            "type": "uint8"
          },
          {
            "internalType": "bool",
            "name": "isTransferFeeCharged",
            "type": "bool"
          },
          {
            "internalType": "uint256",
            "name": "ratio",
            "type": "uint256"
          },
          {
            "internalType": "uint256",
            "name": "maxWeight",
            "type": "uint256"
          },
          {
            "internalType": "uint256",
            "name": "vaultBalance",
            "type": "uint256"
          }
        ],
        "internalType": "struct MassetStructs.Basset[]",
        "name": "bAssets",
        "type": "tuple[]"
      },
      {
        "internalType": "uint256",
        "name": "len",
        "type": "uint256"
      }
    ],
    "payable": false,
    "stateMutability": "view",
    "type": "function"
  },
  {
    "constant": false,
    "inputs": [
      {
        "internalType": "address",
        "name": "_bAsset",
        "type": "address"
      },
      {
        "internalType": "bool",
        "name": "_belowPeg",
        "type": "bool"
      }
    ],
    "name": "handlePegLoss",
    "outputs": [
      {
        "internalType": "bool",
        "name": "alreadyActioned",
        "type": "bool"
      }
    ],
    "payable": false,
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "constant": false,
    "inputs": [
      {
        "internalType": "uint8",
        "name": "_bAssetIndex",
        "type": "uint8"
      },
      {
        "internalType": "address",
        "name": "",
        "type": "address"
      },
      {
        "internalType": "uint256",
        "name": "_increaseAmount",
        "type": "uint256"
      }
    ],
    "name": "increaseVaultBalance",
    "outputs": [],
    "payable": false,
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "constant": false,
    "inputs": [
      {
        "internalType": "uint8[]",
        "name": "_bAssetIndices",
        "type": "uint8[]"
      },
      {
        "internalType": "address[]",
        "name": "",
        "type": "address[]"
      },
      {
        "internalType": "uint256[]",
        "name": "_increaseAmount",
        "type": "uint256[]"
      }
    ],
    "name": "increaseVaultBalances",
    "outputs": [],
    "payable": false,
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "constant": false,
    "inputs": [
      {
        "internalType": "address",
        "name": "_nexus",
        "type": "address"
      },
      {
        "internalType": "address",
        "name": "_mAsset",
        "type": "address"
      },
      {
        "internalType": "address[]",
        "name": "_bAssets",
        "type": "address[]"
      },
      {
        "internalType": "address[]",
        "name": "_integrators",
        "type": "address[]"
      },
      {
        "internalType": "uint256[]",
        "name": "_weights",
        "type": "uint256[]"
      },
      {
        "internalType": "bool[]",
        "name": "_hasTransferFees",
        "type": "bool[]"
      }
    ],
    "name": "initialize",
    "outputs": [],
    "payable": false,
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "constant": true,
    "inputs": [
      {
        "internalType": "uint256",
        "name": "",
        "type": "uint256"
      }
    ],
    "name": "integrations",
    "outputs": [
      {
        "internalType": "address",
        "name": "",
        "type": "address"
      }
    ],
    "payable": false,
    "stateMutability": "view",
    "type": "function"
  },
  {
    "constant": true,
    "inputs": [],
    "name": "mAsset",
    "outputs": [
      {
        "internalType": "address",
        "name": "",
        "type": "address"
      }
    ],
    "payable": false,
    "stateMutability": "view",
    "type": "function"
  },
  {
    "constant": false,
    "inputs": [
      {
        "internalType": "address",
        "name": "_bAsset",
        "type": "address"
      }
    ],
    "name": "negateIsolation",
    "outputs": [],
    "payable": false,
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "constant": true,
    "inputs": [],
    "name": "nexus",
    "outputs": [
      {
        "internalType": "contract INexus",
        "name": "",
        "type": "address"
      }
    ],
    "payable": false,
    "stateMutability": "view",
    "type": "function"
  },
  {
    "constant": false,
    "inputs": [],
    "name": "pause",
    "outputs": [],
    "payable": false,
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "constant": true,
    "inputs": [],
    "name": "paused",
    "outputs": [
      {
        "internalType": "bool",
        "name": "",
        "type": "bool"
      }
    ],
    "payable": false,
    "stateMutability": "view",
    "type": "function"
  },
  {
    "constant": false,
    "inputs": [
      {
        "internalType": "address",
        "name": "_bAsset",
        "type": "address"
      },
      {
        "internalType": "uint256",
        "name": "",
        "type": "uint256"
      },
      {
        "internalType": "bool",
        "name": "",
        "type": "bool"
      }
    ],
    "name": "prepareForgeBasset",
    "outputs": [
      {
        "internalType": "bool",
        "name": "isValid",
        "type": "bool"
      },
      {
        "components": [
          {
            "components": [
              {
                "internalType": "address",
                "name": "addr",
                "type": "address"
              },
              {
                "internalType": "enum MassetStructs.BassetStatus",
                "name": "status",
                "type": "uint8"
              },
              {
                "internalType": "bool",
                "name": "isTransferFeeCharged",
                "type": "bool"
              },
              {
                "internalType": "uint256",
                "name": "ratio",
                "type": "uint256"
              },
              {
                "internalType": "uint256",
                "name": "maxWeight",
                "type": "uint256"
              },
              {
                "internalType": "uint256",
                "name": "vaultBalance",
                "type": "uint256"
              }
            ],
            "internalType": "struct MassetStructs.Basset",
            "name": "bAsset",
            "type": "tuple"
          },
          {
            "internalType": "address",
            "name": "integrator",
            "type": "address"
          },
          {
            "internalType": "uint8",
            "name": "index",
            "type": "uint8"
          }
        ],
        "internalType": "struct MassetStructs.BassetDetails",
        "name": "bInfo",
        "type": "tuple"
      }
    ],
    "payable": false,
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "constant": false,
    "inputs": [
      {
        "internalType": "address[]",
        "name": "_bAssets",
        "type": "address[]"
      },
      {
        "internalType": "uint256[]",
        "name": "",
        "type": "uint256[]"
      },
      {
        "internalType": "bool",
        "name": "",
        "type": "bool"
      }
    ],
    "name": "prepareForgeBassets",
    "outputs": [
      {
        "components": [
          {
            "internalType": "bool",
            "name": "isValid",
            "type": "bool"
          },
          {
            "components": [
              {
                "internalType": "address",
                "name": "addr",
                "type": "address"
              },
              {
                "internalType": "enum MassetStructs.BassetStatus",
                "name": "status",
                "type": "uint8"
              },
              {
                "internalType": "bool",
                "name": "isTransferFeeCharged",
                "type": "bool"
              },
              {
                "internalType": "uint256",
                "name": "ratio",
                "type": "uint256"
              },
              {
                "internalType": "uint256",
                "name": "maxWeight",
                "type": "uint256"
              },
              {
                "internalType": "uint256",
                "name": "vaultBalance",
                "type": "uint256"
              }
            ],
            "internalType": "struct MassetStructs.Basset[]",
            "name": "bAssets",
            "type": "tuple[]"
          },
          {
            "internalType": "address[]",
            "name": "integrators",
            "type": "address[]"
          },
          {
            "internalType": "uint8[]",
            "name": "indexes",
            "type": "uint8[]"
          }
        ],
        "internalType": "struct MassetStructs.ForgePropsMulti",
        "name": "props",
        "type": "tuple"
      }
    ],
    "payable": false,
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "constant": true,
    "inputs": [],
    "name": "prepareRedeemMulti",
    "outputs": [
      {
        "components": [
          {
            "internalType": "uint256",
            "name": "colRatio",
            "type": "uint256"
          },
          {
            "components": [
              {
                "internalType": "address",
                "name": "addr",
                "type": "address"
              },
              {
                "internalType": "enum MassetStructs.BassetStatus",
                "name": "status",
                "type": "uint8"
              },
              {
                "internalType": "bool",
                "name": "isTransferFeeCharged",
                "type": "bool"
              },
              {
                "internalType": "uint256",
                "name": "ratio",
                "type": "uint256"
              },
              {
                "internalType": "uint256",
                "name": "maxWeight",
                "type": "uint256"
              },
              {
                "internalType": "uint256",
                "name": "vaultBalance",
                "type": "uint256"
              }
            ],
            "internalType": "struct MassetStructs.Basset[]",
            "name": "bAssets",
            "type": "tuple[]"
          },
          {
            "internalType": "address[]",
            "name": "integrators",
            "type": "address[]"
          },
          {
            "internalType": "uint8[]",
            "name": "indexes",
            "type": "uint8[]"
          }
        ],
        "internalType": "struct MassetStructs.RedeemPropsMulti",
        "name": "props",
        "type": "tuple"
      }
    ],
    "payable": false,
    "stateMutability": "view",
    "type": "function"
  },
  {
    "constant": true,
    "inputs": [
      {
        "internalType": "address",
        "name": "_input",
        "type": "address"
      },
      {
        "internalType": "address",
        "name": "_output",
        "type": "address"
      },
      {
        "internalType": "bool",
        "name": "_isMint",
        "type": "bool"
      }
    ],
    "name": "prepareSwapBassets",
    "outputs": [
      {
        "internalType": "bool",
        "name": "",
        "type": "bool"
      },
      {
        "internalType": "string",
        "name": "",
        "type": "string"
      },
      {
        "components": [
          {
            "components": [
              {
                "internalType": "address",
                "name": "addr",
                "type": "address"
              },
              {
                "internalType": "enum MassetStructs.BassetStatus",
                "name": "status",
                "type": "uint8"
              },
              {
                "internalType": "bool",
                "name": "isTransferFeeCharged",
                "type": "bool"
              },
              {
                "internalType": "uint256",
                "name": "ratio",
                "type": "uint256"
              },
              {
                "internalType": "uint256",
                "name": "maxWeight",
                "type": "uint256"
              },
              {
                "internalType": "uint256",
                "name": "vaultBalance",
                "type": "uint256"
              }
            ],
            "internalType": "struct MassetStructs.Basset",
            "name": "bAsset",
            "type": "tuple"
          },
          {
            "internalType": "address",
            "name": "integrator",
            "type": "address"
          },
          {
            "internalType": "uint8",
            "name": "index",
            "type": "uint8"
          }
        ],
        "internalType": "struct MassetStructs.BassetDetails",
        "name": "",
        "type": "tuple"
      },
      {
        "components": [
          {
            "components": [
              {
                "internalType": "address",
                "name": "addr",
                "type": "address"
              },
              {
                "internalType": "enum MassetStructs.BassetStatus",
                "name": "status",
                "type": "uint8"
              },
              {
                "internalType": "bool",
                "name": "isTransferFeeCharged",
                "type": "bool"
              },
              {
                "internalType": "uint256",
                "name": "ratio",
                "type": "uint256"
              },
              {
                "internalType": "uint256",
                "name": "maxWeight",
                "type": "uint256"
              },
              {
                "internalType": "uint256",
                "name": "vaultBalance",
                "type": "uint256"
              }
            ],
            "internalType": "struct MassetStructs.Basset",
            "name": "bAsset",
            "type": "tuple"
          },
          {
            "internalType": "address",
            "name": "integrator",
            "type": "address"
          },
          {
            "internalType": "uint8",
            "name": "index",
            "type": "uint8"
          }
        ],
        "internalType": "struct MassetStructs.BassetDetails",
        "name": "",
        "type": "tuple"
      }
    ],
    "payable": false,
    "stateMutability": "view",
    "type": "function"
  },
  {
    "constant": false,
    "inputs": [
      {
        "internalType": "address",
        "name": "_assetToRemove",
        "type": "address"
      }
    ],
    "name": "removeBasset",
    "outputs": [],
    "payable": false,
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "constant": false,
    "inputs": [
      {
        "internalType": "address[]",
        "name": "_bAssets",
        "type": "address[]"
      },
      {
        "internalType": "uint256[]",
        "name": "_weights",
        "type": "uint256[]"
      }
    ],
    "name": "setBasketWeights",
    "outputs": [],
    "payable": false,
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "constant": false,
    "inputs": [
      {
        "internalType": "address",
        "name": "_bAsset",
        "type": "address"
      },
      {
        "internalType": "bool",
        "name": "_flag",
        "type": "bool"
      }
    ],
    "name": "setTransferFeesFlag",
    "outputs": [],
    "payable": false,
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "constant": false,
    "inputs": [],
    "name": "unpause",
    "outputs": [],
    "payable": false,
    "stateMutability": "nonpayable",
    "type": "function"
  }
]
