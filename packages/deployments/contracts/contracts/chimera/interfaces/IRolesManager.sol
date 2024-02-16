// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.17;

import {IBaseConnext} from './IBaseConnext.sol';

interface IRolesManager is IBaseConnext {
  // ============ Events ============

  /**
   * @notice Emitted when the router allowlist is proposed to be removed
   * @param _timestamp - The timestamp when proposal was made
   */
  event RouterAllowlistRemovalProposed(uint256 _timestamp);

  /**
   * @notice Emitted when the router allowlist is removed
   * @param _renounced - Boolean indicating if the ownership of the asset allowlist has been renounced
   */
  event RouterAllowlistRemoved(bool _renounced);

  /**
   * @notice Emitted when an address is revoked from a role
   * @param _revokedAddress - The address that was revoked
   * @param _revokedRole - The role that was revoked
   */
  event RevokeRole(address _revokedAddress, Role _revokedRole);

  /**
   * @notice Emitted when an address is assigned a role
   * @param _account - The address that was assigned a role
   * @param _role - The role that was assigned
   */
  event AssignRole(address _account, Role _role);

  /**
   * @notice Emitted when a new remote instance is added
   * @param _domain - The domain the remote instance is on
   * @param _remote - The address of the remote instance
   * @param _caller - The account that called the function
   */
  event RemoteAdded(uint32 _domain, address _remote, address _caller);

  // ========== Custom Errors ===========

  error RolesManager__proposeRouterAllowlistRemoval_noOwnershipChange();
  error RolesManager__removeRouterAllowlist_noOwnershipChange();
  error RolesManager__removeRouterAllowlist_noProposal();
  error RolesManager__proposeAssetAllowlistRemoval_noOwnershipChange();
  error RolesManager__removeAssetAllowlist_noOwnershipChange();
  error RolesManager__removeAssetAllowlist_noProposal();
  error RolesManager__revokeRole_invalidInput();
  error RolesManager__assignRole_invalidInput(address _account, Role _currentRole, Role _newRole);
  error RolesManager__assignRole_onlyOwnerCanAssignAdmin();
  error RolesManager__assignRole_onlyOwnerCanRevokeAdmin();
  error RolesManager__addRemote_invalidRouter();
  error RolesManager__addRemote_invalidDomain();

  // ========== Logic ===========

  /**
   * @notice Propose to remove the router allowlist
   * @dev Should only be called by Owner or Role.Admin
   * @dev Will fail if all ownership is renounced by modifier
   */
  function proposeRouterAllowlistRemoval() external;

  /**
   * @notice Remove the router allowlist
   */
  function removeRouterAllowlist() external;

  /**
   * @notice Assigns a Role to an address
   * Should only be called by Owner or Role.Admin
   * @param _account - The address to be assigned a Role
   * @param _role - The Role to be assigned
   */
  function assignRole(address _account, Role _role) external;

  /**
   * @notice Use to revoke the Role of an address to None
   * Should only be called by Owner or Role.Admin
   * @dev input address will be assingned default value i.e Role.None under mapping roles
   * @param _revoke - The address to be revoked from it's Role
   */
  function revokeRole(address _revoke) external;

  /**
   * @notice Register the address of a Router contract for the same xApp on a remote chain
   * Should only be called by Owner or Role.Admin
   * @param _domain The domain of the remote xApp Router
   * @param _router The address of the remote xApp Router
   */
  function enrollRemoteRouter(uint32 _domain, bytes32 _router) external;
}
