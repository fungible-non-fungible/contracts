require("dotenv").config();

const HDWalletProvider = require("@truffle/hdwallet-provider");

const mnemonic = process.env.DEV_MNEMONIC;
const deployer = process.env.DEV_PKH;
const bscScanAPIKey = process.env.BSC_SCAN_API_KEY;
const confirmations = process.env.CONFIRMATIONS;

module.exports = {
  networks: {
    development: {
      host: "127.0.0.1",
      port: 8545,
      network_id: "*",
    },
    testnet: {
      provider: () =>
        new HDWalletProvider(
          mnemonic,
          "https://data-seed-prebsc-1-s1.binance.org:8545"
        ),
      network_id: 97,
      confirmations: confirmations,
      timeoutBlocks: 200,
      skipDryRun: true,
      from: deployer,
    },
    mainnet: {
      provider: () =>
        new HDWalletProvider(mnemonic, "https://bsc-dataseed1.binance.org"),
      network_id: 56,
      confirmations: confirmations,
      timeoutBlocks: 200,
      skipDryRun: true,
      from: deployer,
    },
  },

  compilers: {
    solc: {
      version: "0.8.0",
      settings: {
        optimizer: {
          enabled: false,
          runs: 200,
        },
        evmVersion: "byzantium",
      },
    },
  },

  mocha: {
    reporter: "eth-gas-reporter",
    reporterOptions: {
      currency: "USD",
    },
    timeout: 100000,
  },

  plugins: ["truffle-plugin-verify", "truffle-contract-size"],

  db: {
    enabled: false,
  },

  api_keys: {
    bscscan: bscScanAPIKey,
  },
};
