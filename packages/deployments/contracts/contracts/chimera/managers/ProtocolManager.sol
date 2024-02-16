// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {BaseManager} from './BaseManager.sol';
import {Constants} from '../libraries/Constants.sol';
import {IProtocolManager} from '../interfaces/IProtocolManager.sol';
import {IConnectorManager} from '../../messaging/interfaces/IConnectorManager.sol';

abstract contract ProtocolManager is BaseManager, IProtocolManager {
  // ============ External ============

  /// @inheritdoc IProtocolManager
  function proposeNewOwner(address _newlyProposed) external onlyOwner {
    // Contract as source of truth
    if (proposedOwner == _newlyProposed || _newlyProposed == address(0)) {
      revert ProtocolManager__proposeNewOwner_invalidProposal();
    }

    // Sanity check: reasonable proposal
    if (owner == _newlyProposed) revert ProtocolManager__proposeNewOwner_noOwnershipChange();

    proposedOwnershipTimestamp = block.timestamp;
    proposedOwner = _newlyProposed;
    emit OwnershipProposed(_newlyProposed);
  }

  /// @inheritdoc IProtocolManager
  function acceptProposedOwner() external onlyProposedOwner delayElapsed(proposedOwnershipTimestamp) {
    address _newOwner = proposedOwner;
    // Contract as source of truth
    if (owner == _newOwner) revert ProtocolManager__acceptProposedOwner_noOwnershipChange();

    // NOTE: no need to check if proposedOwnershipTimestamp > 0 because
    // the only time this would happen is if the proposedOwner was never
    // set (will fail from modifier) or if the owner == proposedOwner (checked
    // above)

    // Emit event, set new owner, reset timestamp
    delete proposedOwnershipTimestamp;
    delete proposedOwner;
    owner = _newOwner;
    emit OwnershipAccepted(_newOwner);
  }

  /// @inheritdoc IProtocolManager
  function setMaxRoutersPerTransfer(uint256 _newMaxRouters) external onlyOwnerOrRole(Role.Admin) {
    if (_newMaxRouters == 0 || _newMaxRouters == maxRoutersPerTransfer) {
      revert ProtocolManager__setMaxRoutersPerTransfer_invalidMaxRoutersPerTransfer();
    }

    maxRoutersPerTransfer = _newMaxRouters;
    emit MaxRoutersPerTransferUpdated(_newMaxRouters, msg.sender);
  }

  /// @inheritdoc IProtocolManager
  function setRelayerFeeVault(address _relayerFeeVault) external onlyOwnerOrRole(Role.Admin) {
    address _old = relayerFeeVault;
    if (_old == _relayerFeeVault) revert ProtocolManager__setRelayerFeeVault_invalidRelayerFeeVault();

    relayerFeeVault = _relayerFeeVault;
    emit RelayerFeeVaultUpdated(_old, _relayerFeeVault, msg.sender);
  }

  /// @inheritdoc IProtocolManager
  function setLiquidityFeeNumerator(uint256 _numerator) external onlyOwnerOrRole(Role.Admin) {
    // Slightly misleading: the liquidity fee numerator is not the amount charged,
    // but the amount received after fees are deducted (e.g. 9995/10000 would be .005%).
    uint256 _denominator = Constants.BPS_FEE_DENOMINATOR;
    if (_numerator < (_denominator * 95) / 100) revert ProtocolManager__setLiquidityFeeNumerator_tooSmall();
    if (_numerator > _denominator) revert ProtocolManager__setLiquidityFeeNumerator_tooLarge();

    LIQUIDITY_FEE_NUMERATOR = _numerator;
    emit LiquidityFeeNumeratorUpdated(_numerator, msg.sender);
  }

  /// @inheritdoc IProtocolManager
  function setXAppConnectionManager(address _xAppConnectionManager) external onlyOwnerOrRole(Role.Admin) {
    IConnectorManager _manager = IConnectorManager(_xAppConnectionManager);
    if (_manager.localDomain() != domain) {
      revert ProtocolManager__setXAppConnectionManager_domainsDontMatch();
    }

    xAppConnectionManager = _manager;
    emit XAppConnectionManagerSet(_xAppConnectionManager, msg.sender);
  }

  /// @inheritdoc IProtocolManager
  function pause() external onlyOwnerOrRole(Role.Watcher) {
    _paused = true;
    emit Paused();
  }

  /// @inheritdoc IProtocolManager
  function unpause() external onlyOwnerOrRole(Role.Watcher) {
    delete _paused;
    emit Unpaused();
  }
}
