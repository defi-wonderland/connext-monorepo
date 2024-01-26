// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Role} from "../libraries/LibConnextStorage.sol";
import {BaseConnext} from "./BaseConnext.sol";
import {Constants} from "../libraries/Constants.sol";
import {IConnectorManager} from "../../../messaging/interfaces/IConnectorManager.sol";

abstract contract ProtocolManager is BaseConnext {
  // ========== Custom Errors ===========
  error ProtocolManager__proposeNewOwner_invalidProposal();
  error ProtocolManager__proposeNewOwner_noOwnershipChange();
  error ProtocolManager__acceptProposedOwner_noOwnershipChange();
  error ProtocolManager__setMaxRoutersPerTransfer_invalidMaxRoutersPerTransfer();
  error ProtocolManager__onlyProposed_notProposedOwner();
  error ProtocolManager__setRelayerFeeVault_invalidRelayerFeeVault();
  error ProtocolManager__setLiquidityFeeNumerator_tooSmall();
  error ProtocolManager__setLiquidityFeeNumerator_tooLarge();
  error ProtocolManager__setXAppConnectionManager_domainsDontMatch();

  // ============ Events ============
  event Paused();
  event Unpaused();

  // Added
  event OwnershipProposed(address indexed proposedOwner);

  /**
   * @notice Emitted when the maxRoutersPerTransfer variable is updated
   * @param maxRoutersPerTransfer - The maxRoutersPerTransfer new value
   * @param caller - The account that called the function
   */
  event MaxRoutersPerTransferUpdated(uint256 maxRoutersPerTransfer, address caller);

  /**
   * @notice Emitted when the relayerFeeVault variable is updated
   * @param oldVault - The relayerFeeVault old value
   * @param newVault - The relayerFeeVault new value
   * @param caller - The account that called the function
   */
  event RelayerFeeVaultUpdated(address oldVault, address newVault, address caller);

  /**
   * @notice Emitted when the LIQUIDITY_FEE_NUMERATOR variable is updated
   * @param liquidityFeeNumerator - The LIQUIDITY_FEE_NUMERATOR new value
   * @param caller - The account that called the function
   */
  event LiquidityFeeNumeratorUpdated(uint256 liquidityFeeNumerator, address caller);

  /**
   * @notice Emitted `xAppConnectionManager` is updated
   * @param updated - The updated address
   * @param caller - The account that called the function
   */
  event XAppConnectionManagerSet(address updated, address caller);

  // ============ External: Getters ============
  /**
   * @notice Returns the address of the proposed owner.
   */
  function proposed() public view returns (address) {
    return _proposed;
  }

  /**
   * @notice Returns the address of the proposed owner.
   */
  function proposedTimestamp() public view returns (uint256) {
    return _proposedOwnershipTimestamp;
  }

  /**
   * @notice Returns if paused or not.
   */
  function paused() public view returns (bool) {
    return _paused;
  }

  // ============ External ============

  /**
   * @notice Sets the timestamp for an owner to be proposed, and sets the
   * newly proposed owner as step 1 in a 2-step process
   */
  function proposeNewOwner(address newlyProposed) public onlyOwner {
    // Contract as source of truth
    if (_proposed == newlyProposed || newlyProposed == address(0)) {
      revert ProtocolManager__proposeNewOwner_invalidProposal();
    }

    // Sanity check: reasonable proposal
    if (owner == newlyProposed) revert ProtocolManager__proposeNewOwner_noOwnershipChange();

    _setProposed(newlyProposed);
  }

  /**
   * @notice Transfers ownership of the contract to a new account (`newOwner`).
   * Can only be called by the proposed owner.
   */
  function acceptProposedOwner() public onlyProposed delayElapsed(_proposedOwnershipTimestamp) {
    // Contract as source of truth
    if (owner == _proposed) revert ProtocolManager__acceptProposedOwner_noOwnershipChange();

    // NOTE: no need to check if _proposedOwnershipTimestamp > 0 because
    // the only time this would happen is if the _proposed was never
    // set (will fail from modifier) or if the owner == _proposed (checked
    // above)

    // Emit event, set new owner, reset timestamp
    _setOwner(_proposed);
  }

  /**
   * @notice Used to set the max amount of routers a payment can be routed through
   * @param _newMaxRouters The new max amount of routers
   */
  function setMaxRoutersPerTransfer(uint256 _newMaxRouters) external onlyOwnerOrRole(Role.Admin) {
    if (_newMaxRouters == 0 || _newMaxRouters == maxRoutersPerTransfer) {
      revert ProtocolManager__setMaxRoutersPerTransfer_invalidMaxRoutersPerTransfer();
    }

    emit MaxRoutersPerTransferUpdated(_newMaxRouters, msg.sender);

    maxRoutersPerTransfer = _newMaxRouters;
  }

  /**
   * @notice Updates the relayer fee router
   * @param _relayerFeeVault The address of the new router
   */
  function setRelayerFeeVault(address _relayerFeeVault) external onlyOwnerOrRole(Role.Admin) {
    address old = address(relayerFeeVault);
    if (old == _relayerFeeVault) revert ProtocolManager__setRelayerFeeVault_invalidRelayerFeeVault();

    relayerFeeVault = _relayerFeeVault;
    emit RelayerFeeVaultUpdated(old, _relayerFeeVault, msg.sender);
  }

  /**
   * @notice Sets the LIQUIDITY_FEE_NUMERATOR
   * @dev Admin can set LIQUIDITY_FEE_NUMERATOR variable, Liquidity fee should be less than 5%
   * @param _numerator new LIQUIDITY_FEE_NUMERATOR
   */
  function setLiquidityFeeNumerator(uint256 _numerator) external onlyOwnerOrRole(Role.Admin) {
    // Slightly misleading: the liquidity fee numerator is not the amount charged,
    // but the amount received after fees are deducted (e.g. 9995/10000 would be .005%).
    uint256 denominator = Constants.BPS_FEE_DENOMINATOR;
    if (_numerator < (denominator * 95) / 100) revert ProtocolManager__setLiquidityFeeNumerator_tooSmall();

    if (_numerator > denominator) revert ProtocolManager__setLiquidityFeeNumerator_tooLarge();
    LIQUIDITY_FEE_NUMERATOR = _numerator;

    emit LiquidityFeeNumeratorUpdated(_numerator, msg.sender);
  }

  /**
   * @notice Modify the contract the xApp uses to validate Replica contracts
   * @param _xAppConnectionManager The address of the xAppConnectionManager contract
   */
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
    if (_proposed != msg.sender) revert ProtocolManager__onlyProposed_notProposedOwner();
    _;
  }

  function pause() public onlyOwnerOrRole(Role.Watcher) {
    _paused = true;
    emit Paused();
  }

  function unpause() public onlyOwnerOrRole(Role.Watcher) {
    delete _paused;
    emit Unpaused();
  }

  ////// INTERNAL //////
  function _setOwner(address newOwner) private {
    delete _proposedOwnershipTimestamp;
    delete _proposed;
    owner = newOwner;
  }

  function _setProposed(address newlyProposed) private {
    _proposedOwnershipTimestamp = block.timestamp;
    _proposed = newlyProposed;
    emit OwnershipProposed(newlyProposed);
  }
}
