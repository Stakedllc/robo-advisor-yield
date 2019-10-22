module.exports = {
    networks: {
    development: {
      host: "localhost",
      port: 8545,
      network_id: "27",
      gas: 8000000,
      gasPrice: 5000000000
    },
    docker: {
      host: "chain",
      port: 8545,
      network_id: "27",
      gas: 8000000,
      gasPrice: 5000000000
    }
  },
  compilers: {
    solc: {
      version: "0.4.25",
    },
  },
  solc: {
       optimizer: {
           enabled: true,
           runs: 200
       }
   }
};
