import { ChainReader, contractDeployments, getAmbABIs, getContractInterfaces } from "@connext/nxtp-txservice";
import { closeDatabase, getDatabase } from "@connext/nxtp-adapters-database";
import {
  ChainData,
  createLoggingContext,
  Logger,
  RelayerType,
  sendHeartbeat,
  RootManagerMode,
  ModeType,
  SpokeConnectorMode,
  jsonifyError,
  NxtpError,
} from "@connext/nxtp-utils";
import { setupConnextRelayer, setupGelatoRelayer } from "@connext/nxtp-adapters-relayer";
import { SubgraphReader } from "@connext/nxtp-adapters-subgraph";
import { Web3Signer } from "@connext/nxtp-adapters-web3signer";
import { Wallet } from "ethers";

import { NxtpLighthouseConfig } from "../../config";

import { ProposeContext } from "./context";
import { proposeHub, proposeSpoke } from "./operations";

const context: ProposeContext = {} as any;
export const getContext = () => context;

export const makePropose = async (config: NxtpLighthouseConfig, chainData: Map<string, ChainData>) => {
  const { requestContext, methodContext } = createLoggingContext(makePropose.name);

  try {
    context.adapters = {} as any;
    context.chainData = chainData;
    context.config = config;

    // Make logger instance.
    context.logger = new Logger({
      level: context.config.logLevel,
      name: "lighthouse",
      formatters: {
        level: (label) => {
          return { level: label.toUpperCase() };
        },
      },
    });
    context.logger.info("Hello, World! Generated config!", requestContext, methodContext, {
      config: { ...context.config, mnemonic: "*****" },
    });

    // Adapters
    context.adapters.chainreader = new ChainReader(
      context.logger.child({ module: "ChainReader" }),
      context.config.chains,
    );

    // Default to database url if no writer url is provided.
    const databaseWriter = context.config.databaseWriter
      ? context.config.databaseWriter.url
      : context.config.database.url;
    context.adapters.database = await getDatabase(databaseWriter, context.logger);

    context.adapters.wallet = context.config.mnemonic
      ? Wallet.fromMnemonic(context.config.mnemonic)
      : new Web3Signer(context.config.web3SignerUrl!);

    context.adapters.relayers = [];
    for (const relayerConfig of context.config.relayers) {
      const setupFunc =
        relayerConfig.type == RelayerType.Gelato
          ? setupGelatoRelayer
          : RelayerType.Connext
          ? setupConnextRelayer
          : undefined;

      if (!setupFunc) {
        throw new Error(`Unknown relayer configured, relayer: ${relayerConfig}`);
      }

      const relayer = await setupFunc(relayerConfig.url);
      context.adapters.relayers.push({
        instance: relayer,
        apiKey: relayerConfig.apiKey,
        type: relayerConfig.type as RelayerType,
      });
    }
    context.adapters.deployments = contractDeployments;
    context.adapters.contracts = getContractInterfaces();
    context.adapters.ambs = getAmbABIs();
    context.adapters.subgraph = await SubgraphReader.create(
      chainData,
      context.config.environment,
      context.config.subgraphPrefix as string,
    );

    context.logger.info("Propose task setup complete!", requestContext, methodContext, {
      chains: [...Object.keys(context.config.chains)],
    });
    console.log(
      `

        _|_|_|     _|_|     _|      _|   _|      _|   _|_|_|_|   _|      _|   _|_|_|_|_|
      _|         _|    _|   _|_|    _|   _|_|    _|   _|           _|  _|         _|
      _|         _|    _|   _|  _|  _|   _|  _|  _|   _|_|_|         _|           _|
      _|         _|    _|   _|    _|_|   _|    _|_|   _|           _|  _|         _|
        _|_|_|     _|_|     _|      _|   _|      _|   _|_|_|_|   _|      _|       _|

      `,
    );

    // Start the propose task.
    const rootManagerMode: RootManagerMode = await context.adapters.subgraph.getRootManagerMode(config.hubDomain);
    const domains: string[] = Object.keys(config.chains);
    let proposeHubSuccess = true;
    let proposeSpokeSuccess = true;

    for (const domain of domains) {
      const spokeConnectorMode: SpokeConnectorMode = await context.adapters.subgraph.getSpokeConnectorMode(domain);
      if (spokeConnectorMode.mode !== rootManagerMode.mode) {
        context.logger.info("Mode MISMATCH. Stop", requestContext, methodContext, {
          hubMode: rootManagerMode.mode,
          hubDomain: config.hubDomain,
          spokeMode: spokeConnectorMode.mode,
          spokeDomain: domain,
        });
        throw new Error(
          `Unknown mode detected: RootMode - ${JSON.stringify(rootManagerMode)} SpokeMode - ${JSON.stringify(
            spokeConnectorMode,
          )}`,
        );
      }
    }

    if (rootManagerMode.mode === ModeType.OptimisticMode) {
      context.logger.info("In Optimistic Mode", requestContext, methodContext);

      try {
        await proposeHub();
      } catch (e: unknown) {
        context.logger.error("Failed to propose to hub ", requestContext, methodContext, jsonifyError(e as NxtpError), {
          hubDomain: config.hubDomain,
        });

        proposeHubSuccess = false;
      }

      for (const spokeDomain of domains) {
        try {
          await proposeSpoke(spokeDomain);
        } catch (e: unknown) {
          context.logger.error(
            "Failed to propose to spoke ",
            requestContext,
            methodContext,
            jsonifyError(e as NxtpError),
            { spokeDomain },
          );

          proposeSpokeSuccess = false;
        }
      }
    } else if (rootManagerMode.mode === ModeType.SlowMode) {
      context.logger.info("In Slow Mode. No op.", requestContext, methodContext);
    } else {
      throw new Error(`Unknown mode detected: ${JSON.stringify(rootManagerMode)}`);
    }

    if (context.config.healthUrls.propose && proposeHubSuccess && proposeSpokeSuccess) {
      await sendHeartbeat(context.config.healthUrls.propose, context.logger);
    }
  } catch (e: unknown) {
    console.error("Error starting Propose task. Sad! :(", e);
    await closeDatabase();
  } finally {
    context.logger.info("Propose task complete!!!", requestContext, methodContext, {
      chains: [...Object.keys(context.config.chains)],
    });
  }
};
