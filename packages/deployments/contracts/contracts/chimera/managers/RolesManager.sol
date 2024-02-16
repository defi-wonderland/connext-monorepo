// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IRolesManager} from '../interfaces/IRolesManager.sol';
import {BaseManager} from './BaseManager.sol';
import {TypeCasts} from '../../shared/libraries/TypeCasts.sol';

abstract contract RolesManager is BaseManager, IRolesManager {
  /// @inheritdoc IRolesManager
  function proposeRouterAllowlistRemoval() external onlyOwnerOrRole(Role.Admin) {
    // Use contract as source of truth
    // Will fail if all ownership is renounced by modifier
    if (routerAllowlistRemoved) revert RolesManager__proposeRouterAllowlistRemoval_noOwnershipChange();

    // Begin delay, emit event
    _setRouterAllowlistTimestamp();
  }

  /// @inheritdoc IRolesManager
  function removeRouterAllowlist() external onlyOwnerOrRole(Role.Admin) delayElapsed(routerAllowlistTimestamp) {
    // Contract as sounce of truth
    // Will fail if all ownership is renounced by modifier
    if (routerAllowlistRemoved) revert RolesManager__removeRouterAllowlist_noOwnershipChange();

    // Ensure there has been a proposal cycle started
    if (routerAllowlistTimestamp == 0) revert RolesManager__removeRouterAllowlist_noProposal();

    // Set renounced, emit event, reset timestamp to 0
    _setRouterAllowlistRemoved(true);
  }

  /// @inheritdoc IRolesManager
  function assignRole(address _account, Role _role) external onlyOwnerOrRole(Role.Admin) {
    // Use contract as source of truth
    // Will fail if candidate is already added OR input address is addressZero
    if (roles[_account] != Role.None || _account == address(0)) {
      revert RolesManager__assignRole_invalidInput(_account, roles[_account], _role);
    }

    // Only owner can assign admin
    if (_role == Role.Admin && msg.sender != owner) revert RolesManager__assignRole_onlyOwnerCanAssignAdmin();

    roles[_account] = _role;
    emit AssignRole(_account, _role);
  }

  /// @inheritdoc IRolesManager
  function revokeRole(address _revoke) external onlyOwnerOrRole(Role.Admin) {
    // Use contract as source of truth
    // Will fail if candidate isn't assinged any Role OR input address is addressZero
    Role _revokedRole = roles[_revoke];
    if (_revokedRole == Role.None || _revoke == address(0)) revert RolesManager__revokeRole_invalidInput();

    // Only owner can revoke admin
    if (_revokedRole == Role.Admin && msg.sender != owner) revert RolesManager__assignRole_onlyOwnerCanRevokeAdmin();

    roles[_revoke] = Role.None;
    emit RevokeRole(_revoke, _revokedRole);
  }

  /// @inheritdoc IRolesManager
  function enrollRemoteRouter(uint32 _domain, bytes32 _router) external onlyOwnerOrRole(Role.Admin) {
    if (_router == bytes32('')) revert RolesManager__addRemote_invalidRouter();

    // Make sure we aren't setting the current domain (or an empty one) as the connextion.
    if (_domain == 0 || _domain == domain) {
      revert RolesManager__addRemote_invalidDomain();
    }

    remotes[_domain] = _router;
    emit RemoteAdded(_domain, TypeCasts.bytes32ToAddress(_router), msg.sender);
  }

  // ========== Internal ===========
  function _setRouterAllowlistTimestamp() private {
    routerAllowlistTimestamp = block.timestamp;
    emit RouterAllowlistRemovalProposed(block.timestamp);
  }

  function _setRouterAllowlistRemoved(bool _value) private {
    routerAllowlistRemoved = _value;
    delete routerAllowlistTimestamp;
    emit RouterAllowlistRemoved(_value);
  }
}
