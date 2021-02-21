// FOR V2 SAVINGS CONTRACT - MAINNET

const { ethers } = require("ethers");
const axios = require("axios");

require("dotenv").config();

const ether = (n) => {
  return ethers.utils.parseEther(n.toString());
};

const tokens = (n) => ether(n);

const fromWei = (n) => {
  return ethers.utils.formatEther(n);
};
// const ETHER_ADDRESS= '0x0000000000000000000000000000000000000000'
// const EVM_REVERT ='VM Exception while processing transaction: revert'

const init = async () => {
  const provider = ethers.getDefaultProvider("mainnet", {
    infura: process.env.INFURA_KEY_MAINNET,
  });

  const signer = new ethers.Wallet(process.env.PRIVATE_KEY);

 
  const deployer = signer.connect(provider);

 

  const opportunityAddress = "0xDe694e75eCDD9948d39420aCFBb1B9faf9C269C2";

  const sUSD = "0x57ab1ec28d129707052df4df418d58a2d46d5f51";
  const USDC = "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48";
  const TUSD = "0x0000000000085d4780B73119b644AE5ecd22b376";
  const USDT = "0xdac17f958d2ee523a2206206994597c13d831ec7";
  const mUSD = "0xe2f2a5c287993345a840db3b0845fbc70f5935a5";

  const helperAddress = "0xe15aad5d6b7433e5988415274529311f6bf6e8a3";
 

  const saveAddress = "0x30647a72Dc82d7Fbb1123EA74716aB8A317Eac19";
  const basketManagerAddress = "0x66126B4aA2a1C07536Ef8E5e8bD4EfDA1FdEA96D";

  const helperContract = new ethers.Contract(
    helperAddress,
    HelperAbi,
    provider
  );

  const basketContract = new ethers.Contract(
    basketManagerAddress,
    BasketManagerAbi,
    provider
  );

  let result;

  try {
    const getSupply = async (bAsset) => {
      saveBalance = await helperContract.getSaveBalance(
        saveAddress,
        opportunityAddress
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

      return result.bassetQuantityArg.toString(); // or result.output.toString() depending which one should be returned for the bot
    };

    // credits can be redeemed fot any assets, independetly from which asset we deposited. When calling getSupply we have to rememeber that
    // this is the possible supply but if we redeem from one of them it will be affected.
    await getSupply(sUSD);
    await getSupply(TUSD);
    await getSupply(USDC);
    await getSupply(USDT);

    const getDemand = async () => {
      result = await helperContract.getSaveBalance(
        saveAddress,
        opportunityAddress
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
  } catch (err) {
    console.log(err);
  }
};

init();

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
