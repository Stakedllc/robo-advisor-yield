function resetEVM() {

  return new Promise((resolve, reject) => {

    web3.currentProvider.send({
      jsonrpc: '2.0',
      method: 'evm_revert',
      params: ['0x1'],
      id: new Date().getTime()
    }, (err, result) => {

      if (err) {

        return reject(err);

      }

      web3.currentProvider.send({
        jsonrpc: "2.0",
        method: "evm_snapshot",
        params: [],
        id: new Date().getTime()
      }, (err, result) => {

        if (err) {

          return reject(err);

        }

        return resolve(result);

      })

    });

  });

}


function resetEVMTo(snapshotId) {

  return new Promise((resolve, reject) => {

    web3.currentProvider.send({
      jsonrpc: '2.0',
      method: 'evm_revert',
      params: [snapshotId],
      id: new Date().getSeconds()
    }, (err, result) => {

      if (err) {

        return reject(err);

      }

      web3.currentProvider.send({
        jsonrpc: "2.0",
        method: "evm_snapshot",
        params: [],
        id: new Date().getTime()
      }, (err, result) => {

        if (err) {

          return reject(err);

        }

        return resolve(result);

      })

    });

  });

}


function snapshot() {

  return new Promise((resolve, reject) => {

    web3.currentProvider.send({
      jsonrpc: "2.0",
      method: "evm_snapshot",
      params: [],
      id: new Date().getTime()
    }, (err, result) => {

      if (err) {

        return reject(err);

      }

      return resolve(result);

    });

  });

}

module.exports = { resetEVM, resetEVMTo, snapshot };
