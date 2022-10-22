import type { HardhatUserConfig, NetworkUserConfig } from "hardhat/types";
import "@nomiclabs/hardhat-ethers";
import "@nomiclabs/hardhat-web3";
import "@nomiclabs/hardhat-truffle5";
import "@nomiclabs/hardhat-etherscan";
import "hardhat-abi-exporter";
import "hardhat-contract-sizer";
import "solidity-coverage";
import "dotenv/config";

const KEY_TESTNET = 'a132751a011b9a046c786ea0cb42cc2cce80881b398c12631cb2ff45a25ae9cc';
const KEY_MAINNET = 'a132751a011b9a046c786ea0cb42cc2cce80881b398c12631cb2ff45a25ae9cc';

const bscTestnet: NetworkUserConfig = {
  url: "https://data-seed-prebsc-1-s1.binance.org:8545/",
  chainId: 97,
  accounts: [KEY_TESTNET!],
};

const bscMainnet: NetworkUserConfig = {
  url: "https://bsc-dataseed.binance.org/",
  chainId: 56,
  accounts: [KEY_MAINNET!],
};

const config: HardhatUserConfig = {
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {},
    localhost: {
      url: "http://127.0.0.1:9545",
    },
    testnet: bscTestnet,
    mainnet: bscMainnet,
  },
  solidity: {
    compilers: [
      {
        version: "0.5.17",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ]
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts",
  },
  abiExporter: {
    path: "./data/abi",
    clear: true,
    flat: false,
  },
  etherscan: {
    apiKey: "D5K9PXSFMQMRIBV46JF94W5AC5BSGIQ6YB"
  }
};

export default config;
