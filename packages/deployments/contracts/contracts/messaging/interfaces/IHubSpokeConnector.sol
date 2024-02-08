// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.18;

interface IHubSpokeConnector {
  function saveAggregateRoot(bytes32 _aggregateRoot) external;
}
