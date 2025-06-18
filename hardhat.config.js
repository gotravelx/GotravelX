require("@nomicfoundation/hardhat-toolbox");
require("@nomicfoundation/hardhat-chai-matchers");
require("hardhat-gas-reporter");
require("solidity-coverage");

module.exports = {
  solidity: {
    version: "0.8.30",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    columbus: {
      url: "https://columbus.camino.network/ext/bc/C/rpc",
      accounts: ["a5be861de42fa8ab4c4d2f38adea27be85e1043731cae3a278ae2c946277fb37"],
    },
    sepolia: {
      url: "https://eth-sepolia.g.alchemy.com/v2/eHixXo9bzqdGJ-HyWzBM0zb063Yitclv",
      accounts: ["8a2f5fe85bb0d2aba53fe9bfc0f6edff00d76bf719f7e33dff6d2244d59cae05"],
    },
  },
};
