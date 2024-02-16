// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {BaseManager} from './BaseManager.sol';
import {Constants} from '../libraries/Constants.sol';
import {IConnectorManager} from '../../messaging/interfaces/IConnectorManager.sol';
import {IProtocolManager} from '../interfaces/IProtocolManager.sol';

abstract contract ProtocolManager is BaseManager, IProtocolManager {
  // ============ External ============

  /// @inheritdoc IProtocolManager
  function proposeNewOwner(address newlyProposed) public onlyOwner {
    // Contract as source of truth
    if (proposedOwner == newlyProposed || newlyProposed == address(0)) {
      revert ProtocolManager__proposeNewOwner_invalidProposal();
    }

    // Sanity check: reasonable proposal
    if (owner == newlyProposed) revert ProtocolManager__proposeNewOwner_noOwnershipChange();

    _setProposed(newlyProposed);
  }

  /// @inheritdoc IProtocolManager
  function acceptProposedOwner() public onlyProposed delayElapsed(proposedOwnershipTimestamp) {
    // Contract as source of truth
    if (owner == proposedOwner) revert ProtocolManager__acceptProposedOwner_noOwnershipChange();

    // NOTE: no need to check if _proposedOwnershipTimestamp > 0 because
    // the only time this would happen is if the _proposed was never
    // set (will fail from modifier) or if the owner == _proposedOwner (checked
    // above)

    // Emit event, set new owner, reset timestamp
    _setOwner(proposedOwner);
  }

  /// @inheritdoc IProtocolManager
  function setMaxRoutersPerTransfer(uint256 _newMaxRouters) external onlyOwnerOrRole(Role.Admin) {
    if (_newMaxRouters == 0 || _newMaxRouters == maxRoutersPerTransfer) {
      revert ProtocolManager__setMaxRoutersPerTransfer_invalidMaxRoutersPerTransfer();
    }

    emit MaxRoutersPerTransferUpdated(_newMaxRouters, msg.sender);

    maxRoutersPerTransfer = _newMaxRouters;
  }

  /// @inheritdoc IProtocolManager
  function setRelayerFeeVault(address _relayerFeeVault) external onlyOwnerOrRole(Role.Admin) {
    address old = address(relayerFeeVault);
    if (old == _relayerFeeVault) revert ProtocolManager__setRelayerFeeVault_invalidRelayerFeeVault();

    relayerFeeVault = _relayerFeeVault;
    emit RelayerFeeVaultUpdated(old, _relayerFeeVault, msg.sender);
  }

  /// @inheritdoc IProtocolManager
  function setXAppConnectionManager(address _xAppConnectionManager) external onlyOwnerOrRole(Role.Admin) {
    IConnectorManager manager = IConnectorManager(_xAppConnectionManager);
    if (manager.localDomain() != domain) {
      revert ProtocolManager__setXAppConnectionManager_domainsDontMatch();
    }
    emit XAppConnectionManagerSet(_xAppConnectionManager, msg.sender);
    xAppConnectionManager = manager;
  }

  /**
   * @notice Throws if called by any account other than the proposed owner.
   */
  modifier onlyProposed() {
    if (proposedOwner != msg.sender) revert ProtocolManager__onlyProposed_notProposedOwner();
    _;
  }

  /// @inheritdoc IProtocolManager
  function setLiquidityFeeNumerator(uint256 _numerator) external onlyOwnerOrRole(Role.Admin) {
    // Slightly misleading: the liquidity fee numerator is not the amount charged,
    // but the amount received after fees are deducted (e.g. 9995/10000 would be .005%).
    uint256 denominator = Constants.BPS_FEE_DENOMINATOR;
    if (_numerator < (denominator * 95) / 100) revert ProtocolManager__setLiquidityFeeNumerator_tooSmall();

    if (_numerator > denominator) revert ProtocolManager__setLiquidityFeeNumerator_tooLarge();
    LIQUIDITY_FEE_NUMERATOR = _numerator;

    emit LiquidityFeeNumeratorUpdated(_numerator, msg.sender);
  }

  /// @inheritdoc IProtocolManager
  function pause() public onlyOwnerOrRole(Role.Watcher) {
    _paused = true;
    emit Paused();
  }

  /// @inheritdoc IProtocolManager
  function unpause() public onlyOwnerOrRole(Role.Watcher) {
    delete _paused;
    emit Unpaused();
  }

  ////// INTERNAL //////
  function _setOwner(address newOwner) private {
    delete proposedOwnershipTimestamp;
    delete proposedOwner;
    owner = newOwner;
  }

  function _setProposed(address newlyProposed) private {
    proposedOwnershipTimestamp = block.timestamp;
    proposedOwner = newlyProposed;
    emit OwnershipProposed(newlyProposed);
  }
}
