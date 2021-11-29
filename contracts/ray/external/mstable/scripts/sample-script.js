// We require the Hardhat Runtime Environment explicitly here. This is optional 
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");
require('dotenv').config()



const ether = (n) => {
  return ethers.utils.parseEther(n.toString());
};

const tokens = (n) => ether(n);

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile 
  // manually to make sure everything is compiled
  // await hre.run('compile');


  // use  MStableOpportunity for USDC or MStableOpportunityDAI for DAI
  const MStable = await ethers.getContractFactory("MStableOpportunityAll");
  const mStable = await MStable.deploy();
  
  await mStable.deployed();


  const provider = ethers.getDefaultProvider('kovan', {
		infura: process.env.INFURA_KEY_KOVAN
     })
     const options = { gasLimit: 500000}
  // console.log(provider)
   const signer = new ethers.Wallet(process.env.PRIVATE_KEY)

  //  const test = new ethers.Wallet.createRandom()
  //  console.log(test)
   const deployer = await signer.connect(provider)

  const helperAddress = '0x790d4f6ce913278e35192f3cf91b90e53657222b'
  const proxy = '0x70605bdd16e52c86fc7031446d995cf5c7e1b0e7'
   
  const saveAddress = '0x54Ac0bdf4292F7565Af13C9FBEf214eEEB2d0F87'
 

  const mUSD = '0x70605Bdd16e52c86FC7031446D995Cf5c7E1b0e7'

   const storageRayMockUp = '0x948d3D9900bC9C428F5c69dccf6b7Ea24fb6b810'

  const tusdKovan = '0x13512979ade267ab5100878e2e0f485b568328a4'
 
   const DAI = '0x4f96fe3b7a6cf9725f59d353f723c1bdb64ca6aa'
   const USDC = '0xb7a4f3e9097c08da09517b5ab877f7a917224ede'
   const TUSD = '0x1c4a937d171752e1313d70fb16ae2ea02f86303e'

   const mUSDContract = new ethers.Contract(mUSD, ERC20Abi, provider);
  const mUSDSigned = mUSDContract.connect(deployer);
  
  const opportunityContract = new ethers.Contract(mStable.address,OpportunityAbi,provider)
  
  const opportunity = opportunityContract.connect(deployer)

  const USDCContract = new ethers.Contract(USDC, ERC20Abi, provider);
  const USDCSigned = USDCContract.connect(deployer);

  const daiContract = new ethers.Contract(DAI, ERC20Abi, provider);
  const DAISigned = daiContract.connect(deployer);

  const tusdContract = new ethers.Contract(TUSD, ERC20Abi, provider);
  const TUSDSigned = tusdContract.connect(deployer);

      // use USDC or DAI address
  let result = await opportunity.initialize(storageRayMockUp,[DAI,TUSD,USDC],[proxy, proxy, proxy],saveAddress,helperAddress,mUSD)
  let receipt = await result.wait()
  console.log(receipt)
  //expect(mStable.address);
  
  result = await mUSDSigned.approve(proxy, tokens(9900));
  console.log(result);
  receipt = await result.wait();
  console.log(receipt);

  result = await mUSDSigned.approve(saveAddress, tokens(9990));

  receipt = await result.wait();
  console.log(receipt);

      // for testing purpose i created a new function which we will eventually take out
      // use USDC or DAI address
  // result = await opportunity.approveOnce(TUSD, options);
  // console.log(result);
  // receipt = await result.wait();
  // console.log(receipt);
  
  // result = await opportunity.approveOnce(USDC, options);
  // console.log(result);
  // receipt = await result.wait();
  // console.log(receipt);
  
  result = await opportunity.approveOnce(DAI, options); // we used dai but could be anyone since all refer to proxy
  console.log(result);
  receipt = await result.wait();
  console.log(receipt);

  result = await opportunity.approveEach(DAI, options); // we used dai but could be anyone since all refer to proxy
  console.log(result);
  receipt = await result.wait();
  console.log(receipt);

  result = await opportunity.approveEach(TUSD, options); // we used dai but could be anyone since all refer to proxy
  console.log(result);
  receipt = await result.wait();
  console.log(receipt);

  result = await opportunity.approveEach(USDC, options); // we used dai but could be anyone since all refer to proxy
  console.log(result);
  receipt = await result.wait();
  console.log(receipt);


  // this is the step we commented out from approveOnce
  // result = await DAISigned.safeApprove(proxy, tokens(100000), options);
  // console.log(result);
  // receipt = await result.wait();
  // console.log(receipt);

  // result = await USDCSigned.safeApprove(proxy, tokens(100000), options);
  // console.log(result);
  // receipt = await result.wait();
  // console.log(receipt);

  // result = await TUSDSigned.safeApprove(proxy,tokens(100000), options);
  // console.log(result);
  // receipt = await result.wait();
  // console.log(receipt);
  
  result = await mUSDSigned.approve(mStable.address, tokens(9990));
  receipt = await result.wait();
    console.log(receipt);
 
  // We get the contract to deploy
  

  console.log("MyOpportunity deployed to:", mStable.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });



  const OpportunityAbi = [
    {
      "payable": true,
      "stateMutability": "payable",
      "type": "fallback"
    },
    {
      "constant": true,
      "inputs": [],
      "name": "_amount",
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


const ERC20Abi =  [
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