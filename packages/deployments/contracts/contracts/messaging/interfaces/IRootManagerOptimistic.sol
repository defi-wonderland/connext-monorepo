// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.17;

interface IRootManager {
  /*///////////////////////////////////////////////////////////////
                              STRUCTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Struct to store the proposed data
   * @dev The list of the snapshots roots and the domains must be in the
   * same order as the roots insertions on the tree and have the same length.
   * @param snapshotId The id of the snapshots used
   * @param disputeCliff The timestamp when the dispute period is over
   * @param aggregateRoot The new aggregate root
   * @param snapshotsRoots The list of the new roots added to aggregate tree
   * @param domains The list of domains used to fetch the inbound roots from
   */
  struct ProposedData {
    uint256 snapshotId;
    uint256 disputeCliff;
    bytes32 aggregateRoot;
    bytes32[] snapshotsRoots;
    uint32[] domains;
  }

  /*///////////////////////////////////////////////////////////////
                              EVENTS
  //////////////////////////////////////////////////////////////*/

  /**
    @notice Emitted when slow mode is activated.
  */
  event SlowModeActivated();

  /**
    @notice Emitted when optimistic mode is activated.
  */
  event OptimisticModeActivated();

  /**
    @notice Emitted when a new aggregate root is proposed.
    @param _snapshotId The id of the snapshots used
    @param _disputeCliff The timestamp when the dispute period is over
    @param _aggregateRoot The new aggregate root
    @param _snapshotsRoots The list of the new roots added to aggregate tree
    @param _domains The list of domains used to fetch the inbound roots from
  */
  event AggregateRootProposed(
    uint256 _snapshotId,
    uint256 _disputeCliff,
    bytes32 _aggregateRoot,
    bytes32[] _snapshotsRoots,
    uint32[] _domains
  );

  /**
    @notice Emitted when a proposed root is finalized after dispute time is over.
    @param _snapshotId The id of the snapshots used
    @param _aggregateRoot The new aggregate root
    @param _snapshotsRoots The list of the new roots added to aggregate tree
    @param _domains The list of domains
  */
  event ProposedRootFinalized(
    uint256 _snapshotId,
    bytes32 _aggregateRoot,
    bytes32[] _snapshotsRoots,
    uint32[] _domains
  );

  /*///////////////////////////////////////////////////////////////
                              ERRORS
  //////////////////////////////////////////////////////////////*/

  /// @notice Throws if snapshotId is not valid.
  error InvalidSnapshotId(uint256 _snapshotId);

  /// @notice Throws if the domains submitted are invalid.
  error InvalidDomains();

  /// @notice Throws if aggregate root is invalid.
  error InvalidAggregateRoot();

  /// @notice Throws if slow mode is activated.
  error SlowModeOn();

  /// @notice Throws if optimitic mode is activated.
  error OptimsiticModeOn();

  /// @notice Throws if the dispuste cliff hasn't been reached yet.
  error ProposeInProgress();

  /*///////////////////////////////////////////////////////////////
                              VARIABLES
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice The time that the system has in order to detect and invalidate the proposed root.
   * @return _disputeTime Amount of time.
   */
  function DISPUTE_TIME() external returns (uint256 _disputeTime);

  /**
   * @notice True if the system is working in optimistic mode. Otherwise is working in slow mode
   * @return _isActivated Bool that represent if optmistic mode is active or not.
   */
  function optimisticMode() external returns (bool _isActivated);

  /**
    @notice The proposed data.
    @return _proposeData The data that was proposed optimistically
  */
  function proposedAggregateRoot() external returns (ProposedData memory _proposeData);

  /**
    @notice The last finalized aggregate root
    @return _proposeData The data that was proposed optimistically
   */
  function lastFinalizedAggregateRoot() external returns (ProposedData memory _proposeData);

  /*///////////////////////////////////////////////////////////////
                              LOGIC
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Propose a new aggregate root
   * @dev The array snapshot roots is only provided for DA. Also it needs to check which are
   * the current valid domains at that moment and store them on the propose data.
   * This is gonna be used by the off-chain scripts to know which domains to check when validating each proposition.
   * This is to avoid problems if a new domain is added in the middle of an on-going propose.
   *
   * @param _snapshotId The snapshot id used
   * @param _aggregateRoot The new aggregate root
   * @param _snapshotsRoots The array with all snapshots roots used to generate the aggregateRoot
   * @param _domains The array with all the domains in the correct order
   */
  function proposeAggregateRoot(
    uint256 _snapshotId,
    bytes32 _aggregateRoot,
    bytes32[] calldata _snapshotsRoots,
    uint32[] calldata _domains
  ) external;

  /**
   * @notice Finalizes the proposed aggregate root and creates the new last finalized aggregate
   * root that has to be propagated.
   * @dev The system has to be in optimistic mode and the dispute cliff over.
   */
  function finalize() external;

  /**
   * @notice Owner can set the system in slow mode and clear the proposed aggregate root.
   */
  function activateSlowMode() external;

  /**
   * @notice Owner can set the system to optimistic mode.
   * @dev Elements in the queue will be discarded.
   * To save gas we are not deleting the elements from the queue, but moving the last counter to first - 1
   * so we can reassing new elements to those positions in the future.
   * Discarded roots will be included on the upcoming optimistic aggregateRoot.
   */
  function activateOptimisticMode() external;
}
