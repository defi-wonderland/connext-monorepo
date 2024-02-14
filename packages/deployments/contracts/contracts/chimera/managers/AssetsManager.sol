// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IERC20Metadata} from '@openzeppelin/contracts/interfaces/IERC20Metadata.sol';
import {TypeCasts} from '../../shared/libraries/TypeCasts.sol';
import {TypeCasts} from '../../shared/libraries/TypeCasts.sol';
import {TypedMemView} from '../../shared/libraries/TypedMemView.sol';

import {BridgeMessage} from '../libraries/BridgeMessage.sol';

import {BaseManager} from './BaseManager.sol';
import {BridgeToken} from '../helpers/BridgeToken.sol';
import {IBridgeToken} from '../interfaces/IBridgeToken.sol';

abstract contract AssetsManager is BaseManager {
  // ============ Libraries ============

  using TypedMemView for bytes;
  using TypedMemView for bytes29;
  using BridgeMessage for bytes29;

  // ========== Custom Errors ===========
  error AssetsManager__addAssetId_alreadyAdded();
  error AssetsManager__removeAssetId_notAdded();
  error AssetsManager__removeAssetId_invalidParams();
  error AssetsManager__enrollAsset_emptyCanonical();
  error AssetsManager__setupAsset_representationListed();
  error AssetsManager__setupAsset_invalidCanonicalConfiguration();
  error AssetsManager__setupAssetWithDeployedRepresentation_invalidRepresentation();
  error AssetsManager__setupAssetWithDeployedRepresentation_onCanonicalDomain();
  error AssetsManager__onlyReplica_notReplica();
  error AssetsManager__onlyRemoteRouter_notRemote();
  error AssetsManager__handle_notTransfer();
  error AssetsManager__reconcile_alreadyReconciled();

  // ============ Events ============

  /**
   * @notice Emitted when a new asset is added
   * @param key - The key in the mapping (hash of canonical id and domain)
   * @param canonicalId - The canonical identifier of the token
   * @param domain - The domain of the canonical token
   * @param asset - The address of the asset
   * @param caller - The account that called the function
   */
  event AssetAdded(
    bytes32 indexed key, bytes32 indexed canonicalId, uint32 indexed domain, address asset, address caller
  );

  /**
   * @notice Emitted when an asset is removed from allowlists
   * @param key - The hash of the canonical identifier and domain of the token removed
   * @param caller - The account that called the function
   */
  event AssetRemoved(bytes32 indexed key, address caller);

  /**
   * @notice Emitted when `reconciled` is called by the bridge on the destination domain.
   * @param transferId - The unique identifier of the transfer.
   * @param originDomain - The originating domain of the transfer.
   * @param local - The local asset that was provided by the bridge.
   * @param routers - The routers that were reimbursed the bridged token, if fast liquidity was
   * provided for the given transfer.
   * @param amount - The amount that was provided by the bridge.
   * @param caller - The account that called the function
   */
  event Reconciled(
    bytes32 indexed transferId,
    uint32 indexed originDomain,
    address indexed local,
    address[] routers,
    uint256 amount,
    address caller
  );

  /**
   * @notice emitted when tokens are dispensed to an account on this domain
   *         emitted both when fast liquidity is provided, and when the
   *         transfer ultimately settles
   * @param originAndNonce Domain where the transfer originated and the
   *        unique identifier for the message from origin to destination,
   *        combined in a single field ((origin << 32) & nonce)
   * @param token The address of the local token contract being received
   * @param recipient The address receiving the tokens; the original
   *        recipient of the transfer
   * @param liquidityProvider The account providing liquidity
   * @param amount The amount of tokens being received
   */
  event Receive(
    uint64 indexed originAndNonce,
    address indexed token,
    address indexed recipient,
    address liquidityProvider,
    uint256 amount
  );

  // ============ Getters ============
  function approvedAssets(bytes32 _key) public view returns (bool) {
    return tokenConfigs[_key].approval;
  }

  function approvedAssets(TokenId calldata _canonical) public view returns (bool) {
    return approvedAssets(calculateCanonicalHash(_canonical.id, _canonical.domain));
  }

  // ============ Admin functions ============

  /**
   * @notice Used to add supported asset. This is an admin only function
   *
   * @dev When allowlisting the canonical asset, in the event you
   * have a different adopted asset (i.e. PoS USDC on polygon),
   * you should *not* allowlist the adopted asset.
   *
   * The following can only be added on *REMOTE* domains:
   * - `_assetId`
   *
   * @param _canonical - The canonical asset to add by id and domain
   * @param _canonicalDecimals - The decimals of the canonical asset
   * @param _assetId - The used asset id for this domain (e.g. PoS USDC for
   * polygon)
   */
  function setupAsset(
    TokenId calldata _canonical,
    uint8 _canonicalDecimals,
    address _assetId
  ) external onlyOwnerOrRole(Role.Admin) {
    // Calculate the canonical key.
    bytes32 key = calculateCanonicalHash(_canonical.id, _canonical.domain);

    // Get whether you are on canonical
    bool onCanonical = domain == _canonical.domain;
    if (onCanonical) {
      // On the canonical domain, the asset is the canonical address
      address _canonicalAddress = TypeCasts.bytes32ToAddress(_canonical.id);

      // Sanity check: ensure asset ID == canonical address (or empty).
      // This could reflect a user error or miscalculation and lead to unexpected behavior.
      if (_assetId != address(0) && _assetId != _canonicalAddress) {
        revert AssetsManager__setupAsset_invalidCanonicalConfiguration();
      }

      // Enroll the asset.
      _enrollAsset(true, _canonicalDecimals, _canonicalAddress, _canonical, key);
    } else {
      // Enroll the asset.
      _enrollAsset(false, _canonicalDecimals, _assetId, _canonical, key);
    }
  }

  /**
   * @notice Used to remove assets from the allowlist
   * @param _key - The hash of the canonical id and domain to remove (mapping key)
   * @param _assetId - Corresponding asset to remove
   */
  function removeAssetId(bytes32 _key, address _assetId) external onlyOwnerOrRole(Role.Admin) {
    _removeAssetId(_key, _assetId);
  }

  /**
   * @notice Used to remove assets from the allowlist
   * @param _canonical - The canonical id and domain to remove
   * @param _assetId - Corresponding asset to remove
   */
  function removeAssetId(TokenId calldata _canonical, address _assetId) external onlyOwnerOrRole(Role.Admin) {
    bytes32 key = calculateCanonicalHash(_canonical.id, _canonical.domain);
    _removeAssetId(key, _assetId);
  }

  // ============ Private Functions ============

  function _enrollAsset(
    bool _onCanonical,
    uint8 _canonicalDecimals,
    address _asset,
    TokenId calldata _canonical,
    bytes32 _key
  ) internal {
    // TODO: implement
    // Sanity check: canonical ID and domain are not 0.
    if (_canonical.domain == 0 || _canonical.id == bytes32('')) {
      revert AssetsManager__enrollAsset_emptyCanonical();
    }

    // Sanity check: needs approval
    if (tokenConfigs[_key].approval) revert AssetsManager__addAssetId_alreadyAdded();

    /*
  address asset;
  uint8 assetDecimals;
  bool approval;
    */
    // Generate Config
    tokenConfigs[_key] = TokenConfig({
      asset: _asset,
      assetDecimals: _onCanonical ? _canonicalDecimals : IERC20Metadata(_asset).decimals(),
      approval: true
    });

    // Update reverse lookup
    // assetToCanonical[_asset].domain = _canonical.domain;
    // assetToCanonical[_asset].id = _canonical.id;

    // Emit event
    emit AssetAdded({
      key: _key,
      canonicalId: _canonical.id,
      domain: _canonical.domain,
      asset: _asset,
      caller: msg.sender
    });
  }

  /**
   * @notice Used to remove assets from the allowlist
   *
   * @dev When you are removing an asset, `xcall` will fail but `handle` and `execute` will not to
   * allow for inflight transfers to be addressed.
   *
   * @param _key - The hash of the canonical id and domain to remove (mapping key)
   * @param _assetId - Corresponding asset to remove
   */
  function _removeAssetId(bytes32 _key, address _assetId) internal {
    TokenConfig storage config = tokenConfigs[_key];
    // Sanity check: already approval
    if (!config.approval) revert AssetsManager__removeAssetId_notAdded();

    // Sanity check: consistent set of params
    if (config.asset != _assetId) {
      revert AssetsManager__removeAssetId_invalidParams();
    }

    // Delete token config from configs mapping.
    delete tokenConfigs[_key];

    // Delete from reverse lookup
    // delete assetToCanonical[_assetId];

    // Emit event
    emit AssetRemoved(_key, msg.sender);
  }

  // ============ Modifiers ============

  /**
   * @notice Only accept messages from a registered inbox contract.
   */
  modifier onlyReplica() {
    if (!_isReplica(msg.sender)) {
      revert AssetsManager__onlyReplica_notReplica();
    }
    _;
  }

  /**
   * @notice Only accept messages from a remote Router contract.
   * @param _origin The domain the message is coming from.
   * @param _router The address the message is coming from.
   */
  modifier onlyRemoteHandler(uint32 _origin, bytes32 _router) {
    if (!_isRemoteHandler(_origin, _router)) {
      revert AssetsManager__onlyRemoteRouter_notRemote();
    }
    _;
  }

  // ============ External Functions ============

  /**
   * @notice Handles an incoming cross-chain message.
   *
   * @param _origin The origin domain.
   * @param _nonce The unique identifier for the message from origin to destination.
   * @param _sender The sender address.
   * @param _message The message body.
   */
  function handle(
    uint32 _origin,
    uint32 _nonce,
    bytes32 _sender,
    bytes memory _message
  ) external onlyReplica onlyRemoteHandler(_origin, _sender) {
    // Parse token ID and action from message body.
    bytes29 _msg = _message.ref(0).mustBeMessage();
    bytes29 _tokenId = _msg.tokenId();
    bytes29 _action = _msg.action();

    // Sanity check: action must be a valid transfer.
    if (!_action.isTransfer()) {
      revert AssetsManager__handle_notTransfer();
    }

    // If applicable, mint the local asset that corresponds with the message's token ID in the
    // amount specified by the message.
    // Returns the local asset address and message's amount.
    (address _token, uint256 _amount) = _creditTokens(_origin, _nonce, _tokenId, _action);

    // Reconcile the transfer.
    _reconcile(_action.transferId(), _origin, _token, _amount);
  }

  // ============ Internal Functions ============

  /**
   * @notice Reconcile the transfer, marking the transfer ID in storage as authenticated. Reimburses
   * routers with local asset if it was a fast-liquidity transfer (i.e. it was previously executed).
   * @param _transferId Unique identifier of the transfer.
   * @param _origin Origin domain of the transfer.
   * @param _asset Local asset address (representational or canonical).
   * @param _amount The amount of the local asset.
   */
  function _reconcile(bytes32 _transferId, uint32 _origin, address _asset, uint256 _amount) internal {
    // TODO: entirely refactor
    /*   // Ensure the transfer has not already been handled (i.e. previously reconciled).
    // Will be previously reconciled IFF status == reconciled -or- status == executed
    // and there is no path length on the transfers (no fast liquidity)
    TransferStatus status = transferStatus[_transferId];
    if (status != TransferStatus.None && status != TransferStatus.Executed) {
      revert  AssetsManager__reconcile_alreadyReconciled();
    }

    // Mark the transfer as reconciled.
    transferStatus[_transferId] = status == TransferStatus.None
      ? TransferStatus.Reconciled
      : TransferStatus.Completed;

    // If the transfer was executed using fast-liquidity provided by routers, then this value would be set
    // to the participating routers.
    // NOTE: If the transfer was not executed using fast-liquidity, then the funds will be reserved for
    // execution (i.e. funds will be delivered to the transfer's recipient in a subsequent `execute` call).
    address[] memory routers = routedTransfers[_transferId];

    uint256 pathLen = routers.length;
    if (pathLen != 0) {
      // Credit each router that provided liquidity their due 'share' of the asset.
      uint256 routerAmount = _amount / pathLen;
      for (uint256 i; i < pathLen - 1; ) {
        routerBalances[routers[i]][_asset] += routerAmount;
        unchecked {
          ++i;
        }
      }
      // The last router in the multipath will sweep the remaining balance to account for remainder dust.
      uint256 toSweep = routerAmount + (_amount % pathLen);
      routerBalances[routers[pathLen - 1]][_asset] += toSweep;
    }

    emit Reconciled(_transferId, _origin, _asset, routers, _amount, msg.sender); */
  }

  /**
   * @notice Determine whether _potentialReplica is an enrolled Replica from the xAppConnectionManager
   * @return True if _potentialReplica is an enrolled Replica
   */
  function _isReplica(address _potentialReplica) internal view returns (bool) {
    return xAppConnectionManager.isReplica(_potentialReplica);
  }

  /**
   * @notice Return true if the given domain / router is the address of a remote xApp Router
   * @param _domain The domain of the potential remote xApp Router
   * @param _xAppHandler The address of the potential remote xApp handler
   */
  function _isRemoteHandler(uint32 _domain, bytes32 _xAppHandler) internal view returns (bool) {
    return remotes[_domain] == _xAppHandler && _xAppHandler != bytes32(0);
  }

  /**
   * @notice If applicable, mints tokens corresponding to the inbound message action.
   * @dev IFF the asset is representational (i.e. originates from a remote chain), tokens will be minted.
   * Otherwise, the token must be canonical (i.e. we are on the token's home chain), and the corresponding
   * amount will already be available in escrow in this contract.
   *
   * @param _origin The domain of the chain from which the transfer originated.
   * @param _nonce The unique identifier for the message from origin to destination.
   * @param _tokenId The canonical token identifier to credit.
   * @param _action The contents of the transfer message.
   * @return _token The address of the local token contract.
   */
  function _creditTokens(
    uint32 _origin,
    uint32 _nonce,
    bytes29 _tokenId,
    bytes29 _action
  ) internal returns (address, uint256) {
    // TODO: entirely refactor
    /*    bytes32 _canonicalId = _tokenId.id();
    uint32 _canonicalDomain = _tokenId.domain();

    // Load amount once.
    uint256 _amount = _action.amnt();

    // Check for the empty case -- if it is 0 value there is no strict requirement for the
    // canonical information be defined (i.e. you can supply address(0) to xcall). If this
    // is the case, return _token as address(0)
    if (_amount == 0 && _canonicalDomain == 0 && _canonicalId == bytes32(0)) {
      // Emit Receive event and short-circuit remaining logic: no tokens need to be delivered.
      emit Receive(_originAndNonce(_origin, _nonce), address(0), address(this), address(0), _amount);
      return (address(0), 0);
    }

    // Get the token contract for the given tokenId on this chain.
    address _token = _getAsset(
      calculateCanonicalHash(_canonicalId, _canonicalDomain),
      _canonicalId,
      _canonicalDomain
    );

    if (_amount == 0) {
      // Emit Receive event and short-circuit remaining logic: no tokens need to be delivered.
      emit Receive(_originAndNonce(_origin, _nonce), _token, address(this), address(0), _amount);
      return (_token, 0);
    }

    // Emit Receive event.
    emit Receive(_originAndNonce(_origin, _nonce), _token, address(this), address(0), _amount);
    return (_token, _amount); */
  }

  /**
   * @notice Internal utility function that combines
   *         `_origin` and `_nonce`.
   * @dev Both origin and nonce should be less than 2^32 - 1
   * @param _origin Domain of chain where the transfer originated
   * @param _nonce The unique identifier for the message from origin to destination
   * @return Returns (`_origin` << 32) & `_nonce`
   */
  function _originAndNonce(uint32 _origin, uint32 _nonce) internal pure returns (uint64) {
    return (uint64(_origin) << 32) | _nonce;
  }

  // TODO: functions
  // addAssetWithStrategy
  // setStrategyAddress
  // pause / unpauseStrategy()
  // _deployRipToken()
  // _increase / _decreaseBalance()
  // _increase / _decreaseCredits()
  // _increase / _decreaseUnclaimed()
  // settle / moveCredits()
}
