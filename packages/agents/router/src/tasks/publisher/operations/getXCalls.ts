import {
  createLoggingContext,
  jsonifyError,
  SubgraphQueryMetaParams,
  SubgraphQueryByNoncesMetaParams,
  XTransfer,
} from "@connext/nxtp-utils";

import { getContext } from "../publisher";

// Ought to be configured properly for each network; we consult the chain config below.
export const DEFAULT_SAFE_CONFIRMATIONS = 5;

export const getXCalls = async () => {
  const {
    adapters: { cache, subgraph },
    logger,
    config,
  } = getContext();
  const { requestContext, methodContext } = createLoggingContext("pollSubgraph");
  const destinationDomains: string[] = Object.entries(config.chains).map(([chain]) => chain);
  const subgraphQueryMetaParams: Map<string, SubgraphQueryMetaParams> = new Map();
  const allowedDomains = Object.keys(config.chains);
  const latestBlockNumbers = await subgraph.getLatestBlockNumber(allowedDomains);
  for (const domain of allowedDomains) {
    try {
      let latestBlockNumber = 0;
      if (latestBlockNumbers.has(domain)) {
        latestBlockNumber = latestBlockNumbers.get(domain)!;
      }
      if (latestBlockNumber === 0) {
        logger.error(`Error getting the latestBlockNumber, domain: ${domain}}`, requestContext, methodContext);
        continue;
      }

      const safeConfirmations = config.chains[domain].confirmations ?? DEFAULT_SAFE_CONFIRMATIONS;
      let latestNonce = await cache.transfers.getLatestNonce(domain);
      latestNonce = Math.max(latestNonce, config.chains[domain].startNonce ?? 0);
      logger.debug("Selected latestNonce", requestContext, methodContext, { domain, latestNonce });

      subgraphQueryMetaParams.set(domain, {
        maxBlockNumber: latestBlockNumber - safeConfirmations,
        latestNonce: latestNonce == 0 ? 0 : latestNonce + 1, // queries at >= latest nonce, so use 1 larger than whats in the cache
        destinationDomains,
        orderDirection: "asc",
      });
    } catch (err: unknown) {
      logger.error(
        `Error getting the latestBlockNumber, domain: ${domain}}`,
        requestContext,
        methodContext,
        jsonifyError(err as Error),
        { domain },
      );
    }
  }

  if ([...subgraphQueryMetaParams.keys()].length > 0) {
    const { txIdsByDestinationDomain, allTxById, latestNonces, txByOriginDomain } = await subgraph.getOriginXCalls(
      subgraphQueryMetaParams,
    );

    // Collect analytics information for missing nonces
    for (const domain of allowedDomains) {
      const startNonce = subgraphQueryMetaParams.get(domain)?.latestNonce ?? 0;
      const querySize = subgraphQueryMetaParams.get(domain)?.limit ?? 100;
      const txs = txByOriginDomain.get(domain);
      const nonces: number[] = [];
      if (txs) {
        for (const tx of txs) {
          if (tx) {
            nonces.push(tx.xparams.nonce);
          } else {
            logger.warn(`Missing tx for domain ${domain}`, requestContext, methodContext, {
              domain: domain,
              startNonce,
            });
          }
        }
      }
      if (nonces && nonces.length > 0) {
        const resultSize = nonces.length;

        const minNonce = Math.min(...nonces);
        const maxNonce = Math.max(...nonces);
        const missingNonces: number[] = [];
        for (let i = minNonce; i <= maxNonce; i++) {
          if (!nonces.includes(i)) missingNonces.push(i);
        }

        if (missingNonces.length > 0) {
          logger.debug("Missing xcalls from subgraph", requestContext, methodContext, {
            originDomain: domain,
            startNonce,
            querySize,
            resultSize,
            minNonce,
            maxNonce,
            missing: missingNonces.length,
            missingNonces: missingNonces.join(","),
          });

          await cache.transfers.addMissingNonces(domain, missingNonces);
        } else {
          logger.debug("Got all xcalls from subgraph", requestContext, methodContext, {
            originDomain: domain,
            startNonce,
            querySize,
            resultSize,
            minNonce,
            maxNonce,
            length: nonces.length,
            nonces: nonces.join(","),
          });
        }
      }
    }

    for (const [domain, nonce] of latestNonces.entries()) {
      // set nonce now so we don't requery the same transfers
      await cache.transfers.setLatestNonce(domain, nonce ?? 0);
      logger.debug("Set latest nonce", requestContext, methodContext, { domain, nonce });
    }

    if (txIdsByDestinationDomain.size > 0) {
      // filter transfers by unsupported destination domain
      for (const destinationDomain of txIdsByDestinationDomain.keys()) {
        if (!allowedDomains.includes(destinationDomain)) {
          const transferIdsToRemove = txIdsByDestinationDomain.get(destinationDomain);
          for (const transferId of transferIdsToRemove ?? []) {
            allTxById.delete(transferId);
          }

          txIdsByDestinationDomain.delete(destinationDomain);
        }
      }
      const transfers = await subgraph.getDestinationXCalls(txIdsByDestinationDomain, allTxById);
      if (transfers.length === 0) {
        logger.debug("No pending transfers after filtering destination", requestContext, methodContext, {
          subgraphQueryMetaParams: [...subgraphQueryMetaParams.entries()],
        });
      } else {
        await cache.transfers.storeTransfers(transfers as XTransfer[], false);
        for (const transfer of transfers) {
          logger.debug("Added transfer to cache", requestContext, methodContext, { transferId: transfer.transferId });
        }
      }
    } else {
      logger.debug("No pending transfers found within operational domains.", requestContext, methodContext, {
        subgraphQueryMetaParams: [...subgraphQueryMetaParams.entries()],
      });
    }
  }
};

export const getMissingXCalls = async () => {
  const {
    adapters: { cache, subgraph },
    logger,
    config,
  } = getContext();
  const { requestContext, methodContext } = createLoggingContext("pollSubgraph");
  const subgraphQueryByNonceMetaParams: Map<string, SubgraphQueryByNoncesMetaParams> = new Map();
  const allowedDomains = Object.keys(config.chains);
  const latestBlockNumbers = await subgraph.getLatestBlockNumber(allowedDomains);
  for (const domain of allowedDomains) {
    try {
      const missingNonces = await cache.transfers.getMissingNonces(domain, 0, 100);
      let latestBlockNumber = 0;
      if (latestBlockNumbers.has(domain)) {
        latestBlockNumber = latestBlockNumbers.get(domain)!;
      }
      if (latestBlockNumber === 0) {
        logger.error(`Error getting the latestBlockNumber, domain: ${domain}}`, requestContext, methodContext);
        continue;
      }

      const safeConfirmations = config.chains[domain].confirmations ?? DEFAULT_SAFE_CONFIRMATIONS;

      subgraphQueryByNonceMetaParams.set(domain, {
        maxBlockNumber: latestBlockNumber - safeConfirmations,
        nonces: missingNonces,
      });
    } catch (err: unknown) {
      logger.error(
        `Error getting the latestBlockNumber, domain: ${domain}}`,
        requestContext,
        methodContext,
        jsonifyError(err as Error),
        { domain },
      );
    }
  }

  if ([...subgraphQueryByNonceMetaParams.keys()].length > 0) {
    const transfersByNonces = await subgraph.getOriginTransfersByNonces(subgraphQueryByNonceMetaParams);
    const noncesByDomain: Record<string, number[]> = {};

    const txIdsByDestinationDomain: Map<string, string[]> = new Map();
    const allTxById: Map<string, XTransfer> = new Map();
    for (const originTransfer of transfersByNonces) {
      logger.debug("Processing a missing transfer", requestContext, methodContext, {
        transferId: originTransfer.transferId,
      });

      if (noncesByDomain[originTransfer.xparams.originDomain]) {
        noncesByDomain[originTransfer.xparams.originDomain].push(originTransfer.xparams.nonce);
      } else {
        noncesByDomain[originTransfer.xparams.originDomain] = [originTransfer.xparams.nonce];
      }

      if (!allowedDomains.includes(originTransfer.xparams.destinationDomain)) {
        logger.debug("Skipping to query a destination transfer", requestContext, methodContext, {
          transferId: originTransfer.transferId,
          destinationDomain: originTransfer.xparams.destinationDomain,
          allowedDomains,
        });
        continue;
      }

      if (txIdsByDestinationDomain.has(originTransfer.xparams.destinationDomain)) {
        txIdsByDestinationDomain.get(originTransfer.xparams.destinationDomain)?.push(`"${originTransfer.transferId}"`);
      } else {
        txIdsByDestinationDomain.set(originTransfer.xparams.destinationDomain, [`"${originTransfer.transferId}"`]);
      }

      allTxById.set(originTransfer.transferId, originTransfer);
    }

    if (txIdsByDestinationDomain.size > 0) {
      const transfers = await subgraph.getDestinationXCalls(txIdsByDestinationDomain, allTxById);
      if (transfers.length === 0) {
        logger.debug("No pending missing transfers found after filtering destination", requestContext, methodContext);
      } else {
        await cache.transfers.storeTransfers(transfers as XTransfer[], false);
        for (const transfer of transfers) {
          logger.debug("Added missing transfer to cache", requestContext, methodContext, {
            transferId: transfer.transferId,
          });
        }
      }
    } else {
      logger.debug("No pending missing transfers found within operational domains.", requestContext, methodContext);
    }

    for (const domain of allowedDomains) {
      const noncesToRemove = noncesByDomain[domain];
      if (noncesToRemove) await cache.transfers.removeMissingNonces(domain, noncesToRemove);
    }
  }
};
