var HDWalletProvider = require('@truffle/hdwallet-provider');
var mnemonic = "aunt refuse dry discover wheel setup arrive question gloom episode afraid carry";

module.exports = {
  networks: {
    development: {
      provider: function() {
        return new HDWalletProvider(mnemonic, "http://127.0.0.1:8545/", 0, 50);
      },
      network_id: '*',
      gas: 4500000
    }
  },
  compilers: {
    solc: {
      version: "^0.4.24"
    }
  }
};