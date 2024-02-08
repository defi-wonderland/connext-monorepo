// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {BaseManager} from './BaseManager.sol';
import {Role} from '../libraries/LibConnextStorage.sol';
import {TypeCasts} from '../../shared/libraries/TypeCasts.sol';

abstract contract RolesManager is BaseManager {
  // ========== Custom Errors ===========
  error RolesManager__proposeRouterAllowlistRemoval_noOwnershipChange();
  error RolesManager__removeRouterAllowlist_noOwnershipChange();
  error RolesManager__removeRouterAllowlist_noProposal();
  error RolesManager__proposeAssetAllowlistRemoval_noOwnershipChange();
  error RolesManager__removeAssetAllowlist_noOwnershipChange();
  error RolesManager__removeAssetAllowlist_noProposal();
  error RolesManager__revokeRole_invalidInput();
  error RolesManager__assignRole_invalidInput(address _account, Role _currentRole, Role _newRole);
  error RolesManager__addRelayer_alreadyApproved();
  error RolesManager__removeRelayer_notApproved();
  error RolesManager__addSequencer_invalidSequencer();
  error RolesManager__addSequencer_alreadyApproved();
  error RolesManager__removeSequencer_notApproved();
  error RolesManager__addRemote_invalidRouter();
  error RolesManager__addRemote_invalidDomain();

  // ============ Events ============

  event RouterAllowlistRemovalProposed(uint256 timestamp);

  event RouterAllowlistRemoved(bool renounced);

  event RevokeRole(address revokedAddress, Role revokedRole);

  event AssignRole(address account, Role role);

  /**
   * @notice Emitted when a relayer is added or removed from allowlists
   * @param relayer - The relayer address to be added or removed
   * @param caller - The account that called the function
   */
  event RelayerAdded(address relayer, address caller);

  /**
   * @notice Emitted when a relayer is added or removed from allowlists
   * @param relayer - The relayer address to be added or removed
   * @param caller - The account that called the function
   */
  event RelayerRemoved(address relayer, address caller);

  /**
   * @notice Emitted when a sequencer is added or removed from allowlists
   * @param sequencer - The sequencer address to be added or removed
   * @param caller - The account that called the function
   */
  event SequencerAdded(address sequencer, address caller);

  /**
   * @notice Emitted when a sequencer is added or removed from allowlists
   * @param sequencer - The sequencer address to be added or removed
   * @param caller - The account that called the function
   */
  event SequencerRemoved(address sequencer, address caller);

  /**
   * @notice Emitted when a new remote instance is added
   * @param domain - The domain the remote instance is on
   * @param remote - The address of the remote instance
   * @param caller - The account that called the function
   */
  event RemoteAdded(uint32 domain, address remote, address caller);

  // ============ External ============

  /**
   * @notice Indicates if the ownership of the router allowlist has
   * been renounced
   */
  function proposeRouterAllowlistRemoval() public onlyOwnerOrRole(Role.Admin) {
    // Use contract as source of truth
    // Will fail if all ownership is renounced by modifier
    if (routerAllowlistRemoved) revert RolesManager__proposeRouterAllowlistRemoval_noOwnershipChange();

    // Begin delay, emit event
    _setRouterAllowlistTimestamp();
  }

  /**
   * @notice Indicates if the ownership of the asset allowlist has
   * been renounced
   */
  function removeRouterAllowlist() public onlyOwnerOrRole(Role.Admin) delayElapsed(routerAllowlistTimestamp) {
    // Contract as sounce of truth
    // Will fail if all ownership is renounced by modifier
    if (routerAllowlistRemoved) revert RolesManager__removeRouterAllowlist_noOwnershipChange();

    // Ensure there has been a proposal cycle started
    if (routerAllowlistTimestamp == 0) revert RolesManager__removeRouterAllowlist_noProposal();

    // Set renounced, emit event, reset timestamp to 0
    _setRouterAllowlistRemoved(true);
  }

  /**
   * @notice Use to revoke the Role of an address to None
   * Can only be called by Owner or Role.Admin
   * @dev input address will be assingned default value i.e Role.None under mapping roles
   * @param _revoke - The address to be revoked from it's Role
   */
  function revokeRole(address _revoke) public onlyOwnerOrRole(Role.Admin) {
    // Use contract as source of truth
    // Will fail if candidate isn't assinged any Role OR input address is addressZero
    Role revokedRole = roles[_revoke];
    if (revokedRole == Role.None || _revoke == address(0)) revert RolesManager__revokeRole_invalidInput();

    roles[_revoke] = Role.None;
    emit RevokeRole(_revoke, revokedRole);
  }

  function assignRole(address _account, Role _role) public onlyOwnerOrRole(Role.Admin) {
    // Use contract as source of truth
    // Will fail if candidate is already added OR input address is addressZero
    if (roles[_account] != Role.None || _account == address(0)) {
      revert RolesManager__assignRole_invalidInput(_account, roles[_account], _role);
    }

    roles[_account] = _role;
    emit AssignRole(_account, _role);
  }

  /**
   * @notice Used to add approved relayer
   * @param _relayer - The relayer address to add
   */
  function addRelayer(address _relayer) external onlyOwnerOrRole(Role.Admin) {
    if (approvedRelayers[_relayer]) revert RolesManager__addRelayer_alreadyApproved();
    approvedRelayers[_relayer] = true;

    emit RelayerAdded(_relayer, msg.sender);
  }

  /**
   * @notice Used to remove approved relayer
   * @param _relayer - The relayer address to remove
   */
  function removeRelayer(address _relayer) external onlyOwnerOrRole(Role.Admin) {
    if (!approvedRelayers[_relayer]) revert RolesManager__removeRelayer_notApproved();
    delete approvedRelayers[_relayer];

    emit RelayerRemoved(_relayer, msg.sender);
  }

  /**
   * @notice Used to add an approved sequencer to the allowlist.
   * @param _sequencer - The sequencer address to add.
   */
  function addSequencer(address _sequencer) external onlyOwnerOrRole(Role.Admin) {
    if (_sequencer == address(0)) revert RolesManager__addSequencer_invalidSequencer();

    if (approvedSequencers[_sequencer]) revert RolesManager__addSequencer_alreadyApproved();
    approvedSequencers[_sequencer] = true;

    emit SequencerAdded(_sequencer, msg.sender);
  }

  /**
   * @notice Used to remove an approved sequencer from the allowlist.
   * @param _sequencer - The sequencer address to remove.
   */
  function removeSequencer(address _sequencer) external onlyOwnerOrRole(Role.Admin) {
    if (!approvedSequencers[_sequencer]) revert RolesManager__removeSequencer_notApproved();
    delete approvedSequencers[_sequencer];

    emit SequencerRemoved(_sequencer, msg.sender);
  }

  /**
   * @notice Register the address of a Router contract for the same xApp on a remote chain
   * @param _domain The domain of the remote xApp Router
   * @param _router The address of the remote xApp Router
   */
  function enrollRemoteRouter(uint32 _domain, bytes32 _router) external onlyOwnerOrRole(Role.Admin) {
    if (_router == bytes32('')) revert RolesManager__addRemote_invalidRouter();

    // Make sure we aren't setting the current domain (or an empty one) as the connextion.
    if (_domain == 0 || _domain == domain) {
      revert RolesManager__addRemote_invalidDomain();
    }

    remotes[_domain] = _router;
    emit RemoteAdded(_domain, TypeCasts.bytes32ToAddress(_router), msg.sender);
  }

  ////// INTERNAL //////
  function _setRouterAllowlistTimestamp() private {
    routerAllowlistTimestamp = block.timestamp;
    emit RouterAllowlistRemovalProposed(block.timestamp);
  }

  function _setRouterAllowlistRemoved(bool value) private {
    routerAllowlistRemoved = value;
    delete routerAllowlistTimestamp;
    emit RouterAllowlistRemoved(value);
  }
}
