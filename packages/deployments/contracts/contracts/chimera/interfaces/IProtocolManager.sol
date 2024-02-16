// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IProtocolManager {
  // ============ Events ============

  event OwnershipProposed(address indexed _proposedOwner);
  event OwnershipAccepted(address indexed _newOwner);

  /**
   * @notice Emitted when the maxRoutersPerTransfer variable is updated
   * @param _maxRoutersPerTransfer - The maxRoutersPerTransfer new value
   * @param _caller - The account that called the function
   */
  event MaxRoutersPerTransferUpdated(uint256 _maxRoutersPerTransfer, address _caller);

  /**
   * @notice Emitted when the relayerFeeVault variable is updated
   * @param _oldVault - The relayerFeeVault old value
   * @param _newVault - The relayerFeeVault new value
   * @param _caller - The account that called the function
   */
  event RelayerFeeVaultUpdated(address _oldVault, address _newVault, address _caller);

  /**
   * @notice Emitted when the LIQUIDITY_FEE_NUMERATOR variable is updated
   * @param _liquidityFeeNumerator - The LIQUIDITY_FEE_NUMERATOR new value
   * @param _caller - The account that called the function
   */
  event LiquidityFeeNumeratorUpdated(uint256 _liquidityFeeNumerator, address _caller);

  /**
   * @notice Emitted `xAppConnectionManager` is updated
   * @param _updated - The updated address
   * @param _caller - The account that called the function
   */
  event XAppConnectionManagerSet(address _updated, address _caller);

  event Paused();
  event Unpaused();

  // ============ Custom Errors ============

  error ProtocolManager__proposeNewOwner_invalidProposal();
  error ProtocolManager__proposeNewOwner_noOwnershipChange();
  error ProtocolManager__acceptProposedOwner_noOwnershipChange();
  error ProtocolManager__setMaxRoutersPerTransfer_invalidMaxRoutersPerTransfer();
  error ProtocolManager__setRelayerFeeVault_invalidRelayerFeeVault();
  error ProtocolManager__setLiquidityFeeNumerator_tooSmall();
  error ProtocolManager__setLiquidityFeeNumerator_tooLarge();
  error ProtocolManager__setXAppConnectionManager_domainsDontMatch();

  // ============ External ============

  /**
   * @notice Sets the timestamp for an owner to be proposed, and sets the
   * newly proposed owner as step 1 in a 2-step process
   */
  function proposeNewOwner(address _newlyProposed) external;

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
   * @notice Sets the LIQUIDITY_FEE_NUMERATOR
   * @dev Admin can set LIQUIDITY_FEE_NUMERATOR variable, Liquidity fee should be less than 5%
   * @param _numerator new LIQUIDITY_FEE_NUMERATOR
   */
  function setLiquidityFeeNumerator(uint256 _numerator) external;

  /**
   * @notice Modify the contract the xApp uses to validate Replica contracts
   * @param _xAppConnectionManager The address of the xAppConnectionManager contract
   */
  function setXAppConnectionManager(address _xAppConnectionManager) external;

  function pause() external;
  function unpause() external;
}
