// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {TypeCasts} from "../../../shared/libraries/TypeCasts.sol";
import {TypeCasts} from "../../../shared/libraries/TypeCasts.sol";
import {TypedMemView} from "../../../shared/libraries/TypedMemView.sol";

import {BridgeMessage} from "../libraries/BridgeMessage.sol";

import {Role, TokenId, TokenConfig, DestinationTransferStatus} from "../libraries/LibConnextStorage.sol";
import {BaseManager} from "./BaseManager.sol";
import {BridgeToken} from "../helpers/BridgeToken.sol";
import {IBridgeToken} from "../interfaces/IBridgeToken.sol";

abstract contract AssetsManager is BaseManager {
  // ============ Libraries ============

  using TypedMemView for bytes;
  using TypedMemView for bytes29;
  using BridgeMessage for bytes29;

  // ========== Custom Errors ===========
  error AssetsManager__addAssetId_alreadyAdded();
  error AssetsManager__addAssetId_badMint();
  error AssetsManager__addAssetId_badBurn();
  error AssetsManager__removeAssetId_notAdded();
  error AssetsManager__removeAssetId_invalidParams();
  error AssetsManager__removeAssetId_remainsCustodied();
  error AssetsManager__updateDetails_localNotFound();
  error AssetsManager__updateDetails_onlyRemote();
  error AssetsManager__updateDetails_notApproved();
  error AssetsManager__enrollAdoptedAndLocalAssets_emptyCanonical();
  error AssetsManager__setupAsset_representationListed();
  error AssetsManager__setupAsset_invalidCanonicalConfiguration();
  error AssetsManager__setupAssetWithDeployedRepresentation_invalidRepresentation();
  error AssetsManager__setupAssetWithDeployedRepresentation_onCanonicalDomain();
  error AssetsManager__setLiquidityCap_notCanonicalDomain();
  error AssetsManager__onlyReplica_notReplica();
  error AssetsManager__onlyRemoteRouter_notRemote();
  error AssetsManager__handle_notTransfer();
  error AssetsManager__reconcile_alreadyReconciled();
  error AssetsManager__reconcile_noPortalRouter();


  // ============ Events ============

  /**
   * @notice emitted when a representation token contract is deployed
   * @param domain the domain of the chain where the canonical asset is deployed
   * @param id the bytes32 address of the canonical token contract
   * @param representation the address of the newly locally deployed representation contract
   */
  event TokenDeployed(uint32 indexed domain, bytes32 indexed id, address indexed representation);

  /**
   * @notice Emitted when a liquidity cap is updated
   * @param key - The key in the mapping (hash of canonical id and domain)
   * @param canonicalId - The canonical identifier of the token the local <> adopted AMM is for
   * @param domain - The domain of the canonical token for the local <> adopted amm
   * @param cap - The newly enforced liquidity cap (if it is 0, no cap is enforced)
   * @param caller - The account that called the function
   */
  event LiquidityCapUpdated(
    bytes32 indexed key,
    bytes32 indexed canonicalId,
    uint32 indexed domain,
    uint256 cap,
    address caller
  );

  /**
   * @notice Emitted when a new asset is added
   * @param key - The key in the mapping (hash of canonical id and domain)
   * @param canonicalId - The canonical identifier of the token the local <> adopted AMM is for
   * @param domain - The domain of the canonical token for the local <> adopted amm
   * @param adoptedAsset - The address of the adopted (user-expected) asset
   * @param localAsset - The address of the local asset
   * @param caller - The account that called the function
   */
  event AssetAdded(
    bytes32 indexed key,
    bytes32 indexed canonicalId,
    uint32 indexed domain,
    address adoptedAsset,
    address localAsset,
    address caller
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

  function getCustodiedAmount(bytes32 _key) public view returns (uint256) {
    return tokenConfigs[_key].custodied;
  }

  // ============ Admin functions ============

  /**
   * @notice Used to add supported asset This is an admin only function
   *
   * @dev When allowlisting the canonical asset, all representational assets would be
   * allowlisted as well. In the event you have a different adopted asset (i.e. PoS USDC
   * on polygon), you should *not* allowlist the adopted asset. The stable swap pool
   * address used should allow you to swap between the local <> adopted asset.
   *
   * If a representation has been deployed at any point, `setupAssetWithDeployedRepresentation`
   * should be used instead.
   *
   * The following can only be added on *REMOTE* domains:
   * - `_adoptedAssetId`
   * - `_stableSwapPool`
   *
   * Whereas the `_cap` can only be added on the canonical domain
   *
   * @param _canonical - The canonical asset to add by id and domain. All representations
   * will be allowlisted as well
   * @param _canonicalDecimals - The decimals of the canonical asset (will be used for deployed
   * representation)
   * @param _representationName - The name to be used for the deployed asset
   * @param _representationSymbol - The symbol used for the deployed asset
   * @param _adoptedAssetId - The used asset id for this domain (e.g. PoS USDC for
   * polygon)
   * @param _stableSwapPool - The address of the local stableswap pool, if it exist
   */
  function setupAsset(
    TokenId calldata _canonical,
    uint8 _canonicalDecimals,
    string memory _representationName,
    string memory _representationSymbol,
    address _adoptedAssetId,
    address _stableSwapPool,
    uint256 _cap
  ) external onlyOwnerOrRole(Role.Admin) returns (address _local) {
    // Calculate the canonical key.
    bytes32 key = calculateCanonicalHash(_canonical.id, _canonical.domain);

    bool onCanonical = _canonical.domain == domain;
    if (onCanonical) {
      // On the canonical domain, the local is the canonical addres
      _local = TypeCasts.bytes32ToAddress(_canonical.id);

      // Sanity check: ensure adopted asset ID == canonical address (or empty).
      // This could reflect a user error or miscalculation and lead to unexpected behavior.
      // NOTE: Since we're on canonical domain, there should be no stableswap pool provided.
      if ((_adoptedAssetId != address(0) && _adoptedAssetId != _local) || _stableSwapPool != address(0)) {
        revert AssetsManager__setupAsset_invalidCanonicalConfiguration();
      }

      // Enroll the asset. Pass in address(0) for adopted: it should use the local asset (i.e. the
      // canonical asset in this case) instead for both adopted and local.

      // TODO: Fix stack too deep in the line below
      //_enrollAdoptedAndLocalAssets(true, _canonicalDecimals, address(0), _local, address(0), _canonical, _cap, key);
    } else {
      // Cannot already have an assigned representation.
      // NOTE: *If* it does, it can still be replaced with `setupAssetWithDeployedRepresentation`
      if (tokenConfigs[key].representation != address(0) || tokenConfigs[key].representationDecimals != 0) {
        revert AssetsManager__setupAsset_representationListed();
      }

      // On remote, deploy a local representation.
      _local = _deployRepresentation(
        _canonical.id,
        _canonical.domain,
        _canonicalDecimals,
        _representationName,
        _representationSymbol
      );
      // Enroll the asset.
      // TODO: Fix stack too deep in the line below
      /*
      _enrollAdoptedAndLocalAssets(
        false,
        _canonicalDecimals,
        _adoptedAssetId,
        _local,
        _stableSwapPool,
        _canonical,
        0,
        key
      );*/
    }
  }

  /**
   * @notice Used to add supported assets, without deploying a unique representation
   * asset, and instead using what admins have provided. This is an admin only function
   *
   * @dev This function does very minimal checks to ensure the correct `_representation`
   * token is used. The only enforced checks are:
   * - Bridge can mint, and balance of bridge will increase
   * - Bridge can burn, and balance of bridge will decrease
   *
   * However, there are many things that must be checked manually to avoid enrolling a bad
   * representation:
   * - decimals must always be equal to canonical decimals
   * - regular `mint`, `burn`, `ERC20` functionality could be implemented improperly
   * - the required interface functions (see `IBridgeToken`) may not be implemented
   * - upgradeability could interfere with required functionality
   *
   * Using this method allows admins to override existing local tokens, and should be used
   * carefully.
   *
   * @param _canonical - The canonical asset to add by id and domain. All representations
   * will be whitelisted as well
   * @param _representation - The address of the representative asset
   * @param _adoptedAssetId - The used asset id for this domain (e.g. PoS USDC for
   * polygon)
   * @param _stableSwapPool - The address of the local stableswap pool, if it exist
   */
  function setupAssetWithDeployedRepresentation(
    TokenId calldata _canonical,
    address _representation,
    address _adoptedAssetId,
    address _stableSwapPool
  ) external onlyOwnerOrRole(Role.Admin) returns (address) {
    if (_representation == address(0)) {
      revert AssetsManager__setupAssetWithDeployedRepresentation_invalidRepresentation();
    }

    if (_canonical.domain == domain) {
      revert AssetsManager__setupAssetWithDeployedRepresentation_onCanonicalDomain();
    }

    // Calculate the canonical key.
    bytes32 key = calculateCanonicalHash(_canonical.id, _canonical.domain);

    _enrollAdoptedAndLocalAssets(
      false,
      IERC20Metadata(_representation).decimals(),
      _adoptedAssetId,
      _representation,
      _stableSwapPool,
      _canonical,
      0,
      key
    );

    return _representation;
  }

  /**
   * @notice Adds a stable swap pool for the local <> adopted asset.
   * @dev Must pass in the _canonical information so it can be emitted in event
   */
  function updateLiquidityCap(TokenId calldata _canonical, uint256 _updated) external onlyOwnerOrRole(Role.Admin) {
    bytes32 key = calculateCanonicalHash(_canonical.id, _canonical.domain);
    _setLiquidityCap(_canonical, _updated, key);
  }

  /**
   * @notice Used to remove assets from the allowlist
   * @param _key - The hash of the canonical id and domain to remove (mapping key)
   * @param _adoptedAssetId - Corresponding adopted asset to remove
      * @param _representation - Corresponding representation asset to remove

   */
  function removeAssetId(
    bytes32 _key,
    address _adoptedAssetId,
    address _representation
  ) external onlyOwnerOrRole(Role.Admin) {
    TokenId memory canonical = adoptedToCanonical[_adoptedAssetId];
    _removeAssetId(_key, _adoptedAssetId, _representation, canonical);
  }

  /**
   * @notice Used to remove assets from the allowlist
   * @param _canonical - The canonical id and domain to remove
   * @param _adoptedAssetId - Corresponding adopted asset to remove
   * @param _representation - Corresponding representation asset to remove
   */
  function removeAssetId(
    TokenId calldata _canonical,
    address _adoptedAssetId,
    address _representation
  ) external onlyOwnerOrRole(Role.Admin) {
    bytes32 key = calculateCanonicalHash(_canonical.id, _canonical.domain);
    _removeAssetId(key, _adoptedAssetId, _representation, _canonical);
  }

  /**
   * @notice Used to update the name and symbol of a local token
   * @param _canonical - The canonical id and domain to remove
   * @param _name - The new name
   * @param _symbol - The new symbol
   */
  function updateDetails(
    TokenId calldata _canonical,
    string memory _name,
    string memory _symbol
  ) external onlyOwnerOrRole(Role.Admin) {
    bytes32 key = calculateCanonicalHash(_canonical.id, _canonical.domain);
    address local = _getConfig(key).representation;
    if (local == address(0)) {
      revert AssetsManager__updateDetails_localNotFound();
    }

    // Can only happen on remote domains
    if (domain == _canonical.domain) {
      revert AssetsManager__updateDetails_onlyRemote();
    }

    // ensure asset is currently approved because `canonicalToRepresentation` does
    // not get cleared when asset is removed from allowlist
    if (!tokenConfigs[key].approval) {
      revert AssetsManager__updateDetails_notApproved();
    }

    // make sure the asset is still active
    IBridgeToken(local).setDetails(_name, _symbol);
  }

  // ============ Private Functions ============

  function _enrollAdoptedAndLocalAssets(
    bool _onCanonical,
    uint8 _localDecimals,
    address _adopted,
    address _local,
    address _stableSwapPool,
    TokenId calldata _canonical,
    uint256 _cap,
    bytes32 _key
  ) internal {
    // Sanity check: canonical ID and domain are not 0.
    if (_canonical.domain == 0 || _canonical.id == bytes32("")) {
      revert AssetsManager__enrollAdoptedAndLocalAssets_emptyCanonical();
    }

    // Get true adopted
    bool adoptedIsLocal = _adopted == address(0);
    address adopted = adoptedIsLocal ? _local : _adopted;

    // Get whether you are on canonical
    bool onCanonical = domain == _canonical.domain;

    // Sanity check: needs approval
    if (tokenConfigs[_key].approval) revert AssetsManager__addAssetId_alreadyAdded();

    // Sanity check: bridge can mint / burn on remote
    if (!onCanonical) {
      IBridgeToken candidate = IBridgeToken(_local);
      uint256 starting = candidate.balanceOf(address(this));
      candidate.mint(address(this), 1);
      if (candidate.balanceOf(address(this)) != starting + 1) {
        revert AssetsManager__addAssetId_badMint();
      }
      candidate.burn(address(this), 1);
      if (candidate.balanceOf(address(this)) != starting) {
        revert AssetsManager__addAssetId_badBurn();
      }
    }

    // Generate Config
    // NOTE: Using address(0) for stable swap, then using `_addStableSwap`. Slightly less
    // efficient, but preserves event Same case for cap / custodied.
    // NOTE: IFF on canonical domain, `representation` must *always* be address(0)!
    tokenConfigs[_key] = TokenConfig(
      _onCanonical ? address(0) : _local, // representation
      _localDecimals, // representationDecimals
      adopted, // adopted
      adoptedIsLocal ? _localDecimals : IERC20Metadata(adopted).decimals(), // adoptedDecimals
      address(0), // adoptedToLocalExternalPools, see note
      true, // approval
      0, // cap, see note
      0 // custodied, see note
    );

    // Update reverse lookups
    // Update the adopted mapping using convention of local == adopted iff (_adopted == address(0))
    adoptedToCanonical[adopted].domain = _canonical.domain;
    adoptedToCanonical[adopted].id = _canonical.id;

    if (!_onCanonical) {
      // Update the local <> canonical. Representations only exist on non-canonical domain
      representationToCanonical[_local].domain = _canonical.domain;
      representationToCanonical[_local].id = _canonical.id;
      // Update swap (on the canonical domain, there is no representation / pool).

      // TODO: check below removal
      //_addStableSwapPool(_canonical, _stableSwapPool, _key);
    } else if (_cap > 0) {
      // Update cap (only on canonical domain).
      _setLiquidityCap(_canonical, _cap, _key);
    }

    // Emit event
    emit AssetAdded(_key, _canonical.id, _canonical.domain, adopted, _local, msg.sender);
  }

  /**
   * @notice Used to add a cap on amount of custodied canonical asset
   * @dev The `custodied` amount will only increase in real time as router liquidity
   * and xcall are used and the cap is set (i.e. if cap is removed, `custodied` values are
   * no longer updated or enforced).
   *
   * When the `cap` is updated, the `custodied` value is set to the balance of the contract,
   * which is distinct from *retrievable* funds from the contracts (i.e. could include the
   * value someone just sent directly to the contract). Whenever you are updating the cap, you
   * should set the value with this in mind.
   *
   * @param _canonical - The canonical TokenId to add (domain and id)
   * @param _updated - The updated liquidity cap value
   * @param _key - The hash of the canonical id and domain
   */
  function _setLiquidityCap(TokenId calldata _canonical, uint256 _updated, bytes32 _key) internal {
    if (domain != _canonical.domain) {
      revert AssetsManager__setLiquidityCap_notCanonicalDomain();
    }
    // Update the stored cap
    tokenConfigs[_key].cap = _updated;

    if (_updated > 0) {
      // Update the custodied value to be the balance of this contract
      address canonical = TypeCasts.bytes32ToAddress(_canonical.id);
      tokenConfigs[_key].custodied = IERC20Metadata(canonical).balanceOf(address(this));
    }

    emit LiquidityCapUpdated(_key, _canonical.id, _canonical.domain, _updated, msg.sender);
  }

  /**
   * @notice Used to remove assets from the allowlist
   *
   * @dev When you are removing an asset, `xcall` will fail but `handle` and `execute` will not to
   * allow for inflight transfers to be addressed. Similarly, the `repayAavePortal` function will
   * work.
   *
   * @param _key - The hash of the canonical id and domain to remove (mapping key)
   * @param _adoptedAssetId - Corresponding adopted asset to remove
   * @param _representation - Corresponding representation asset (i.e. bridged asset) to remove.
   * @param _canonical - The TokenId (canonical ID and domain) of the asset.
   */
  function _removeAssetId(
    bytes32 _key,
    address _adoptedAssetId,
    address _representation,
    TokenId memory _canonical
  ) internal {
    TokenConfig storage config = tokenConfigs[_key];
    // Sanity check: already approval
    if (!config.approval) revert AssetsManager__removeAssetId_notAdded();

    // Sanity check: consistent set of params
    if (config.adopted != _adoptedAssetId || config.representation != _representation)
      revert AssetsManager__removeAssetId_invalidParams();

    bool onCanonical = domain == _canonical.domain;
    if (onCanonical) {
      // Sanity check: no value custodied if on canonical domain
      address canonicalAsset = TypeCasts.bytes32ToAddress(_canonical.id);
      // Check custodied amount for the given canonical asset addres
      // NOTE: if the `cap` is not set, the `custodied` value will not continue to be updated,
      // so you must use the `balanceOf` for accurate accounting. If there are funds held
      // on these contracts, then when you remove the asset id, the assets cannot be bridged back and
      // become worthles This means the bridged assets would become worthles
      // An attacker could prevent admins from removing an asset by sending funds to this contract,
      // but all of the liquidity should already be removed before this function is called.
      if (IERC20Metadata(canonicalAsset).balanceOf(address(this)) > 0) {
        revert AssetsManager__removeAssetId_remainsCustodied();
      }
    } else {
      // Sanity check: supply is 0 if on remote domain.
      if (IBridgeToken(_representation).totalSupply() > 0) {
        revert AssetsManager__removeAssetId_remainsCustodied();
      }
    }

    // Delete token config from configs mapping.
    // NOTE: we do NOT delete the representation entries from the config. This is
    // done to prevent multiple representations being deployed in `setupAsset`
    delete tokenConfigs[_key].adopted;
    delete tokenConfigs[_key].adoptedDecimals;
    delete tokenConfigs[_key].adoptedToLocalExternalPools;
    delete tokenConfigs[_key].approval;
    delete tokenConfigs[_key].cap;
    // NOTE: custodied will always be 0 at this point

    // Delete from reverse lookups
    delete representationToCanonical[_representation];
    delete adoptedToCanonical[_adoptedAssetId];

    // Emit event
    emit AssetRemoved(_key, msg.sender);
  }

  /**
   * @notice Deploy and initialize a new token contract
   * @dev Each token contract is a proxy which
   * points to the token upgrade beacon
   * @return _token the address of the token contract
   */
  function _deployRepresentation(
    bytes32 _id,
    uint32 _domain,
    uint8 _decimals,
    string memory _name,
    string memory _symbol
  ) internal returns (address _token) {
    // deploy the token contract
    _token = address(new BridgeToken(_decimals, _name, _symbol));
    // emit event upon deploying new token
    emit TokenDeployed(_domain, _id, _token);
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
    DestinationTransferStatus status = transferStatus[_transferId];
    if (status != DestinationTransferStatus.None && status != DestinationTransferStatus.Executed) {
      revert  AssetsManager__reconcile_alreadyReconciled();
    }

    // Mark the transfer as reconciled.
    transferStatus[_transferId] = status == DestinationTransferStatus.None
      ? DestinationTransferStatus.Reconciled
      : DestinationTransferStatus.Completed;

    // If the transfer was executed using fast-liquidity provided by routers, then this value would be set
    // to the participating routers.
    // NOTE: If the transfer was not executed using fast-liquidity, then the funds will be reserved for
    // execution (i.e. funds will be delivered to the transfer's recipient in a subsequent `execute` call).
    address[] memory routers = routedTransfers[_transferId];

    // If fast transfer was made using portal liquidity, portal debt must be repaid first.
    // NOTE: Routers can repay any-amount out-of-band using the `repayAavePortal` method
    // or by interacting with the aave contracts directly.
    uint256 portalTransferAmount = portalDebt[_transferId] + portalFeeDebt[_transferId];

    uint256 pathLen = routers.length;
    // Sanity check: ensure a router took on the credit risk.
    if (portalTransferAmount != 0 && pathLen != 1) {
      revert  AssetsManager__reconcile_noPortalRouter();
    }

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
    address _token = _getLocalAsset(
      calculateCanonicalHash(_canonicalId, _canonicalDomain),
      _canonicalId,
      _canonicalDomain
    );

    if (_amount == 0) {
      // Emit Receive event and short-circuit remaining logic: no tokens need to be delivered.
      emit Receive(_originAndNonce(_origin, _nonce), _token, address(this), address(0), _amount);
      return (_token, 0);
    }

    // Mint the tokens into circulation on this chain.
    if (!_isLocalOrigin(_token)) {
      // If the token is of remote origin, mint the representational asset into circulation here.
      // NOTE: The bridge tokens should be distributed to their intended recipient outside
      IBridgeToken(_token).mint(address(this), _amount);
    }
    // NOTE: If the tokens are locally originating - meaning they are the canonical asset - then they
    // would be held in escrow in this contract. If we're receiving this message, it must mean
    // corresponding representational assets circulating on a remote chain were burnt when it was sent.

    // Emit Receive event.
    emit Receive(_originAndNonce(_origin, _nonce), _token, address(this), address(0), _amount);
    return (_token, _amount); */
  }

  /*   function _isLocalOrigin(address _token) internal view returns (bool) {
    return AssetLogic.isLocalOrigin(_token, s);
  } */

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
