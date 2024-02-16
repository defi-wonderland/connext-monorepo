// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IProtocolManager {
  // ============ Custom Errors ============
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

  // ============ External ============

  /**
   * @notice Sets the timestamp for an owner to be proposed, and sets the
   * newly proposed owner as step 1 in a 2-step process
   */
  function proposeNewOwner(address newlyProposed) external;

  /**
   * @notice Transfers ownership of the contract to a new account (`newOwner`).
   * Can only be called by the proposed owner.
   */
  function acceptProposedOwner() external;

  /**
   * @notice Used to set the max amount of routers a payment can be routed through
   * @param _newMaxRouters The new max amount of routers
   */
  function setMaxRoutersPerTransfer(uint256 _newMaxRouters) external;

  /**
   * @notice Updates the relayer fee router
   * @param _relayerFeeVault The address of the new router
   */
  function setRelayerFeeVault(address _relayerFeeVault) external;

  /**
   * @notice Modify the contract the xApp uses to validate Replica contracts
   * @param _xAppConnectionManager The address of the xAppConnectionManager contract
   */
  function setXAppConnectionManager(address _xAppConnectionManager) external;

  /**
   * @notice Sets the LIQUIDITY_FEE_NUMERATOR
   * @dev Admin can set LIQUIDITY_FEE_NUMERATOR variable, Liquidity fee should be less than 5%
   * @param _numerator new LIQUIDITY_FEE_NUMERATOR
   */
  function setLiquidityFeeNumerator(uint256 _numerator) external;

  function pause() external;

  function unpause() external;
}
