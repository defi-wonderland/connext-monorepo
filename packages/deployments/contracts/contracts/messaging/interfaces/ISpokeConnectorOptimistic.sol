// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.17;

interface SpokeConnector {
  /*///////////////////////////////////////////////////////////////
                              EVENTS
  //////////////////////////////////////////////////////////////*/

  /**
    @notice Emitted when a snapshot root is saved in the mapping.
    @param _snapshotId The id of the snapshots saved
    @param _root The inbound root saved as snapshot root
    @param _count The number of insertions the tree has
  */
  event SnapshotRootSaved(uint256 _snapshotId, bytes32 _root, uint256 _count);

  /*///////////////////////////////////////////////////////////////
                              VARIABLES
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Duration of the snapshot
   */
  function SNAPSHOT_DURATION() external returns (uint256 _snapshotDuration);

  /**
   * @notice Mapping of the snapshot roots for a specific index. Used for data availability for off-chain scripts
   */
  function snapshotRoots(uint256 _snapshotId) external returns (bytes32 _snapshotRoot);

  /*///////////////////////////////////////////////////////////////
                              LOGIC
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice This function gets the current snapshot id
   * @dev The value is calculated through an internal function to reuse code and save gas
   * @return _snapshotId The current snapshot id
   */
  function getCurrentSnapshotId() external view returns (uint256 _snapshotId);

  /**
   * @notice This function gets the last completed snapshot id
   * @dev The value is calculated through an internal function to reuse code and save gas
   * @return _snapshotId The last completed snapshot id
   */
  function getLastCompletedSnapshotId() external view returns (uint256 _snapshotId);
}
