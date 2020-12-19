// We require the Hardhat Runtime Environment explicitly here. This is optional 
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");
require('dotenv').config()
async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile 
  // manually to make sure everything is compiled
  // await hre.run('compile');
  const MStable = await ethers.getContractFactory("MStableOpportunity");
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

  
  const opportunityContract = new ethers.Contract(mStable.address,OpportunityAbi,provider)
  
  const opportunity = opportunityContract.connect(deployer)

  const result = await opportunity.initialize(storageRayMockUp,[tusdKovan],[proxy],saveAddress,helperAddress,mUSD)
  const receipt = await result.wait()
  console.log(receipt)
  //expect(mStable.address);
  
  
 
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
      "name": "approveOnce",
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
      "name": "getBalance",
      "outputs": [
        {
          "internalType": "uint256",
          "name": "",
          "type": "uint256"
        }
      ],
      "payable": false,
      "stateMutability": "nonpayable",
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