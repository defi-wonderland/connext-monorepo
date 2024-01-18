import { createLoggingContext, NxtpError } from "@connext/nxtp-utils";

import { sendWithRelayerWithBackup } from "../../../mockable";
import { NoChainIdForDomain } from "../errors";
import { getContext } from "../propagate";

export const finalizeSpoke = async (spokeDomain: string) => {
  const {
    logger,
    config,
    adapters: { chainreader, contracts, relayers, subgraph, database },
    chainData,
  } = getContext();
  const { requestContext, methodContext } = createLoggingContext(finalizeSpoke.name);

  if (spokeDomain == config.hubDomain) {
    logger.info("Skipping finalize operation on hub", requestContext, methodContext, { spokeDomain });
    return;
  }

  logger.info("Starting finalize operation on spoke", requestContext, methodContext, { spokeDomain });

  const spokeChainId = chainData.get(spokeDomain)?.chainId;

  if (!spokeChainId) {
    throw new NoChainIdForDomain(spokeDomain, requestContext, methodContext);
  }
  const spokeConnectorAddress = config.chains[spokeDomain].deployments.spokeConnector;

  const currentProposedRoot = await database.getCurrentProposedOptimisticRoot(spokeDomain);

  if (!currentProposedRoot) {
    //Throw
    logger.info("No current proposed spoke optmisitc root found. Ending spoke run.", requestContext, methodContext, {
      spokeDomain,
    });
    return;
  }

  const _proposedAggregateRoot = currentProposedRoot.aggregateRoot;
  const _rootTimestamp = currentProposedRoot.rootTimestamp;
  const _endOfDispute = currentProposedRoot.endOfDispute;

  const latestBlockNumbers = await subgraph.getLatestBlockNumber([spokeDomain]);
  let latestBlockNumber: number | undefined = undefined;
  if (latestBlockNumbers.has(spokeDomain)) {
    latestBlockNumber = latestBlockNumbers.get(spokeDomain)!;
  }

  if (!latestBlockNumber) {
    logger.error("Error getting the latestBlockNumber for domain.", requestContext, methodContext, undefined, {
      spokeDomain,
      latestBlockNumber,
      latestBlockNumbers,
    });
    return;
  }

  if (_endOfDispute > latestBlockNumber) {
    logger.error(
      "Dispute window is still active. End of dispute block is ahead of latest block",
      requestContext,
      methodContext,
      undefined,
      {
        currentProposedRoot,
        latestBlockNumber,
        _endOfDispute,
      },
    );
    return;
  }

  const encodedDataForRelayer = contracts.spokeConnector.encodeFunctionData("finalize", [
    _proposedAggregateRoot,
    _rootTimestamp,
    _endOfDispute,
  ]);

  logger.info("Got params for sending", requestContext, methodContext, {
    _proposedAggregateRoot,
    _rootTimestamp,
    _endOfDispute,
    encodedDataForRelayer,
  });

  try {
    const { taskId } = await sendWithRelayerWithBackup(
      spokeChainId,
      spokeDomain,
      spokeConnectorAddress,
      encodedDataForRelayer,
      relayers,
      chainreader,
      logger,
      requestContext,
    );
    logger.info("finalize tx sent to spoke", requestContext, methodContext, { spokeDomain, taskId });
  } catch (e: unknown) {
    logger.error("Error at sendWithRelayerWithBackup", requestContext, methodContext, e as NxtpError, {
      spokeChainId,
      spokeDomain,
      spokeConnectorAddress,
      encodedDataForRelayer,
    });
  }
};
