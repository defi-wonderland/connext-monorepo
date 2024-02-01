import "hardhat-diamond-abi";
import "@typechain/hardhat";
import "@nomiclabs/hardhat-ethers";
import "@nomiclabs/hardhat-waffle";
import "hardhat-gas-reporter";
import "hardhat-deploy";
import "solidity-coverage";
import "@nomiclabs/hardhat-etherscan";
import "@openzeppelin/hardhat-upgrades";
import "hardhat-contract-sizer";
import "hardhat-abi-exporter";
import "@matterlabs/hardhat-zksync-deploy";
import "@matterlabs/hardhat-zksync-solc";
import "@matterlabs/hardhat-zksync-verify";
import { HardhatUserConfig } from "hardhat/types";
import * as tdly from "@tenderly/hardhat-tenderly";

import "./hardhat/tasks/addWatcher";
import "./hardhat/tasks/approveRouter";
import "./hardhat/tasks/addAdmin";
import "./hardhat/tasks/setupAsset";
import "./hardhat/tasks/addLiquidity";
import "./hardhat/tasks/mintTestToken";
import "./hardhat/tasks/setupTestRouter";
import "./hardhat/tasks/renounceOwnership";
import "./hardhat/tasks/proposeTransferOwnership";
import "./hardhat/tasks/setAggregator";
import "./hardhat/tasks/setDexPrice";
import "./hardhat/tasks/setDirectPrice";
import "./hardhat/tasks/debugCustomError";
import "./hardhat/tasks/decodeInputData";
import "./hardhat/tasks/removeRouter";
import "./hardhat/tasks/enrollHandlers";
import "./hardhat/tasks/dustSelfAccounts";
import "./hardhat/tasks/xcall";
import "./hardhat/tasks/readBalances";
import "./hardhat/tasks/preflight";
import "./hardhat/tasks/addRelayer";
import "./hardhat/tasks/executeEstimateGas";
import "./hardhat/tasks/exportAbi";
import "./hardhat/tasks/stableswap/initializeSwap";
import "./hardhat/tasks/stableswap/addSwapLiquidity";
import "./hardhat/tasks/stableswap/removeSwapLiquidity";
import "./hardhat/tasks/stableswap/setSwapFees";
import "./hardhat/tasks/connector/send";
import "./hardhat/tasks/connector/setDelayBlocks";
import "./hardhat/tasks/rootmanager/propagate";
import "./hardhat/tasks/rootmanager/setDelayBlocks";
import "./hardhat/tasks/setMirrorConnectors";
import "./hardhat/tasks/addSequencer";
import "./hardhat/tasks/setXAppConnectionManager";
import "./hardhat/tasks/queryRoots";
import "./hardhat/tasks/submitExitProof";
import "./hardhat/tasks/addConnectors";
import "./hardhat/tasks/connector/proveAndProcess";
import "./hardhat/tasks/addSender";
import "./hardhat/tasks/connector/processFromRoot";
import "./hardhat/tasks/connector/redeem";
//import "./hardhat/tasks/connector/claimPolygonZk";
import "./hardhat/tasks/pause";
import "./hardhat/tasks/unpause";
import "./hardhat/tasks/bumpTransfer";
import "./hardhat/tasks/rootmanager/enrollAdminConnector";
import "./hardhat/tasks/connector/addSpokeRootToAggregate";
import "./hardhat/tasks/connector/receiveHubAggregateRoot";
import "./hardhat/tasks/connector/wormholeDeliver";
import "./hardhat/tasks/connector/claimLinea";
import "./hardhat/tasks/connector/setOptimisticMode";
import "./hardhat/tasks/ignoreForgeTests";
import { hardhatNetworks } from "./hardhat/src/config";

tdly.setup({
  automaticVerifications: false,
});

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.8.17",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
      {
        version: "0.7.6", // for @suma-tx/memview-sol
        settings: {},
      },
    ],
  },
  zksolc: {
    version: "1.3.5",
    compilerSource: "binary",
    settings: {},
  },
  paths: {
    artifacts: "./artifacts",
    sources: "./contracts",
    tests: "./test/old",
  },
  defaultNetwork: "hardhat",
  namedAccounts: {
    deployer: { default: 0 },
    alice: { default: 1 },
    bob: { default: 2 },
    rando: { default: 3 },
  },
  networks: hardhatNetworks,
  etherscan: {
    apiKey: {
      // testnets
      rinkeby: process.env.ETHERSCAN_API_KEY!,
      kovan: process.env.ETHERSCAN_API_KEY!,
      ropsten: process.env.ETHERSCAN_API_KEY!,
      goerli: process.env.ETHERSCAN_API_KEY!,
      "optimism-goerli": process.env.OPTIMISM_ETHERSCAN_API_KEY!,
      "gnosis-testnet": process.env.GNOSISSCAN_API_KEY!,
      mumbai: process.env.POLYGONSCAN_API_KEY!,
      chapel: process.env.BNBSCAN_API_KEY!,

      // mainnets
      mainnet: process.env.ETHERSCAN_API_KEY!,
      matic: process.env.POLYGONSCAN_API_KEY!,
      optimism: process.env.OPTIMISM_ETHERSCAN_API_KEY!,
      bnb: process.env.BNBSCAN_API_KEY!,
      "arbitrum-one": process.env.ARBISCAN_API_KEY!,
      xdai: process.env.GNOSISSCAN_API_KEY!,
      linea: process.env.LINEASCAN_API_KEY!,
    },
    customChains: [
      {
        network: "optimism-goerli",
        chainId: 420,
        urls: {
          apiURL: "https://blockscout.com/optimism/goerli/api",
          browserURL: "https://blockscout.com/optimism/goerli",
        },
      },
      {
        network: "gnosis-testnet",
        chainId: 10200,
        urls: {
          apiURL: "https://blockscout.chiadochain.net/api",
          browserURL: "https://blockscout.chiadochain.net",
        },
      },
      {
        network: "zksync2-testnet",
        chainId: 280,
        urls: {
          apiURL: "hhttps://zksync2-testnet.zkscan.io/api",
          browserURL: "https://zksync2-testnet.zkscan.io",
        },
      },
    ],
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS == "true",
  },
  diamondAbi: {
    // (required) The name of your Diamond ABI.
    name: "Connext",
    // (optional) An array of strings, matched against fully qualified contract names, to
    // determine which contracts are included in your Diamond ABI.
    include: [
      "TokenFacet",
      "BaseConnextFacet",
      "BridgeFacet",
      "DiamondCutFacet",
      "DiamondLoupeFacet",
      "NomadFacet",
      "ProposedOwnableFacet",
      "RelayerFacet",
      "RoutersFacet",
      "StableSwapFacet",
      "PortalFacet",
    ],
    strict: false,
    filter: function (abiElement, index, fullAbi, fullyQualifiedName) {
      const contractName = fullyQualifiedName.split(":")[1];
      if (abiElement.type === "error" && !abiElement.name.includes(contractName)) {
        return false;
      }

      return true;
    },
  },
  tenderly: {
    username: process.env.TENDERLY_ACCOUNT_ID!,
    project: process.env.TENDERLY_PROJECT_SLUG!,
    accessKey: process.env.TENDERLY_ACCESS_KEY!,
    privateVerification: false, // if true, contracts will be verified privately, if false, contracts will be verified publicly
  },
  typechain: {
    outDir: "artifacts/typechain-types",
  },
  abiExporter: {
    path: "./abi",
    runOnCompile: true,
    clear: true,
    spacing: 2,
    format: "fullName",
  },
};

export default config;
