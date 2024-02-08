// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {TypeCasts} from '../../shared/libraries/TypeCasts.sol';
import {Constants} from '../libraries/Constants.sol';
import {BaseManager} from './BaseManager.sol';

abstract contract RoutersManager is BaseManager {
  // ========== Custom Errors ===========
  error RoutersManager__acceptProposedRouterOwner_notElapsed();
  error RoutersManager__acceptProposedRouterOwner_badCaller();
  error RoutersManager__initializeRouter_configNotEmpty();
  error RoutersManager__setRouterRecipient_notNewRecipient();
  error RoutersManager__onlyRouterOwner_notRouterOwner();
  error RoutersManager__unapproveRouter_routerEmpty();
  error RoutersManager__unapproveRouter_notAdded();
  error RoutersManager__approveRouter_routerEmpty();
  error RoutersManager__approveRouter_alreadyAdded();
  error RoutersManager__proposeRouterOwner_notNewOwner();
  error RoutersManager__proposeRouterOwner_badRouter();
  error RoutersManager__addLiquidityForRouter_routerEmpty();
  error RoutersManager__addLiquidityForRouter_amountIsZero();
  error RoutersManager__addLiquidityForRouter_badRouter();
  error RoutersManager__removeRouterLiquidity_recipientEmpty();
  error RoutersManager__removeRouterLiquidity_amountIsZero();
  error RoutersManager__removeRouterLiquidity_insufficientFunds();
  error RoutersManager__removeRouterLiquidityFor_notOwner();
  error RoutersManager__setRouterOwner_noChange();

  error RoutersManager__getApprovedCanonicalId_notAllowlisted();

  // ============ Events ============

  /**
   * @notice Emitted when a new router is added
   * @param router - The address of the added router
   * @param caller - The account that called the function
   */
  event RouterAdded(address indexed router, address caller);

  /**
   * @notice Emitted when an existing router is removed
   * @param router - The address of the removed router
   * @param caller - The account that called the function
   */
  event RouterRemoved(address indexed router, address caller);

  /**
   * @notice Emitted when the recipient of router is updated
   * @param router - The address of the added router
   * @param prevRecipient  - The address of the previous recipient of the router
   * @param newRecipient  - The address of the new recipient of the router
   */
  event RouterRecipientSet(address indexed router, address indexed prevRecipient, address indexed newRecipient);

  /**
   * @notice Emitted when the owner of router is proposed
   * @param router - The address of the added router
   * @param prevProposed  - The address of the previous proposed
   * @param newProposed  - The address of the new proposed
   */
  event RouterOwnerProposed(address indexed router, address indexed prevProposed, address indexed newProposed);

  /**
   * @notice Emitted when the owner of router is accepted
   * @param router - The address of the added router
   * @param prevOwner  - The address of the previous owner of the router
   * @param newOwner  - The address of the new owner of the router
   */
  event RouterOwnerAccepted(address indexed router, address indexed prevOwner, address indexed newOwner);

  /**
   * @notice Emitted when a router adds a config via `addRouterConfig`
   * @dev This does not confer permissions onto the router, only the configuration
   * @param router The router initialized
   *
   */
  event RouterInitialized(address indexed router);

  /**
   * @notice Emitted when a router adds liquidity to the contract
   * @param router - The address of the router the funds were credited to
   * @param local - The address of the token added (all liquidity held in local asset)
   * @param key - The hash of the canonical id and domain
   * @param amount - The amount of liquidity added
   * @param caller - The account that called the function
   */
  event RouterLiquidityAdded(address indexed router, address local, bytes32 key, uint256 amount, address caller);

  /**
   * @notice Emitted when a router withdraws liquidity from the contract
   * @param router - The router you are removing liquidity from
   * @param to - The address the funds were withdrawn to
   * @param local - The address of the token withdrawn
   * @param amount - The amount of liquidity withdrawn
   * @param caller - The account that called the function
   */
  event RouterLiquidityRemoved(
    address indexed router, address to, address local, bytes32 key, uint256 amount, address caller
  );

  // ============ Modifiers ============

  /**
   * @notice Asserts caller is the router owner
   */
  modifier onlyRouterOwner(address _router) {
    if (routerConfigs[_router].owner != msg.sender) revert RoutersManager__onlyRouterOwner_notRouterOwner();
    _;
  }

  // ============ Getters ==============

  function LIQUIDITY_FEE_DENOMINATOR() public pure returns (uint256) {
    return Constants.BPS_FEE_DENOMINATOR;
  }

  /**
   * @notice Returns the approved router for the given router address
   * @param _router The relevant router address
   */
  function getRouterApproval(address _router) public view returns (bool) {
    return routerConfigs[_router].approved;
  }

  /**
   * @notice Returns the recipient for the specified router
   * @dev The recipient (if set) receives all funds when router liquidity is removed
   * @param _router The relevant router address
   */
  function getRouterRecipient(address _router) public view returns (address) {
    return routerConfigs[_router].recipient;
  }

  /**
   * @notice Returns the router owner if it is set, or the router itself if not
   * @param _router The relevant router address
   */
  function getRouterOwner(address _router) public view returns (address) {
    return routerConfigs[_router].owner;
  }

  /**
   * @notice Returns the currently proposed router owner
   * @dev All routers must wait for the delay timeout before accepting a new owner
   * @param _router The relevant router address
   */
  function getProposedRouterOwner(address _router) public view returns (address) {
    return routerConfigs[_router].proposed;
  }

  /**
   * @notice Returns the currently proposed router owner timestamp
   * @dev All routers must wait for the delay timeout before accepting a new owner
   * @param _router The relevant router address
   */
  function getProposedRouterOwnerTimestamp(address _router) public view returns (uint256) {
    return routerConfigs[_router].proposedTimestamp;
  }

  // ============ Admin methods ==============

  /**
   * @notice Used to allowlist a given router
   * @param _router Router address to setup
   */
  function approveRouter(address _router) external onlyOwnerOrRole(Role.RouterAdmin) {
    // Sanity check: not empty
    if (_router == address(0)) revert RoutersManager__approveRouter_routerEmpty();

    // Sanity check: needs approval
    if (routerConfigs[_router].approved) revert RoutersManager__approveRouter_alreadyAdded();

    // Approve router
    routerConfigs[_router].approved = true;

    // Emit event
    emit RouterAdded(_router, msg.sender);
  }

  /**
   * @notice Used to remove routers that can transact crosschain
   * @param _router Router address to remove
   */
  function unapproveRouter(address _router) external onlyOwnerOrRole(Role.RouterAdmin) {
    // Sanity check: not empty
    if (_router == address(0)) revert RoutersManager__unapproveRouter_routerEmpty();

    // Sanity check: needs removal
    RouterConfig memory config = routerConfigs[_router];
    if (!config.approved) revert RoutersManager__unapproveRouter_notAdded();

    // Update approvals in config mapping
    delete routerConfigs[_router].approved;

    // Emit event
    emit RouterRemoved(_router, msg.sender);
  }

  // ============ Public methods ==============

  /**
   * @notice Sets the designated recipient for a router
   * @dev Router should only be able to set this once otherwise if router key compromised,
   * no problem is solved since attacker could just update recipient
   * @param _router Router address to set recipient
   * @param _recipient Recipient Address to set to router
   */
  function setRouterRecipient(address _router, address _recipient) external onlyRouterOwner(_router) {
    _setRouterRecipient(_router, _recipient, routerConfigs[_router].recipient);
  }

  /**
   * @notice Current owner or router may propose a new router owner
   * @dev If routers burn their ownership, they can no longer update the recipient
   * @param _router Router address to set recipient
   * @param _proposed Proposed owner Address to set to router
   */
  function proposeRouterOwner(address _router, address _proposed) external onlyRouterOwner(_router) {
    // NOTE: If routers burn their ownership, they can no longer update the recipient

    // Check that proposed is different than current owner
    RouterConfig memory config = routerConfigs[_router];
    if (config.owner == _proposed) revert RoutersManager__proposeRouterOwner_notNewOwner();

    // Check that proposed is different than current proposed
    if (config.proposed == _proposed) revert RoutersManager__proposeRouterOwner_badRouter();

    // Set proposed owner + timestamp
    routerConfigs[_router].proposed = _proposed;
    routerConfigs[_router].proposedTimestamp = block.timestamp;

    // Emit event
    emit RouterOwnerProposed(_router, config.proposed, _proposed);
  }

  /**
   * @notice New router owner must accept role, or previous if proposed is 0x0
   * @param _router Router address to set recipient
   */
  function acceptProposedRouterOwner(address _router) external {
    RouterConfig memory config = routerConfigs[_router];

    // Check timestamp has passed
    if (block.timestamp - config.proposedTimestamp <= Constants.GOVERNANCE_DELAY) {
      revert RoutersManager__acceptProposedRouterOwner_notElapsed();
    }

    // Check the caller
    address expected = config.proposed == address(0) ? config.owner : config.proposed;
    if (msg.sender != expected) {
      revert RoutersManager__acceptProposedRouterOwner_badCaller();
    }

    // Update the current owner
    _setRouterOwner(_router, config.proposed, config.owner);

    // Reset proposal + timestamp
    if (config.proposed != address(0)) {
      delete routerConfigs[_router].proposed;
    }
    delete routerConfigs[_router].proposedTimestamp;
  }

  /**
   * @notice Can be called by anyone to set a config for their router (the msg.sender)
   * @dev Does not set allowlisting permissions, only owner and recipient
   * @param _owner The owner (can change recipient, proposes new owners)
   * @param _recipient Where liquidity will be withdrawn to
   */
  function initializeRouter(address _owner, address _recipient) external {
    // Ensure the config is empty
    RouterConfig memory config = routerConfigs[msg.sender];
    if (
      config.owner != address(0) || config.recipient != address(0) || config.proposed != address(0)
        || config.proposedTimestamp > 0
    ) {
      revert RoutersManager__initializeRouter_configNotEmpty();
    }

    // Default owner should be router
    if (_owner == address(0)) {
      _owner = msg.sender;
    }
    // Update routerOwner (zero address possible)
    _setRouterOwner(msg.sender, _owner, address(0));

    // Update router recipient (fine to have no recipient provided)
    if (_recipient != address(0)) {
      _setRouterRecipient(msg.sender, _recipient, address(0));
    }

    // Emit event
    emit RouterInitialized(msg.sender);
  }

  /**
   * @notice This is used by anyone to increase a router's available liquidity for a given asset.
   * @dev The liquidity will be held in the local asset, which is the representation if you
   * are *not* on the canonical domain, and the canonical asset otherwise.
   * @param _amount - The amount of liquidity to add for the router
   * @param _local - The address of the asset you're adding liquidity for. If adding liquidity of the
   * native asset, routers may use `address(0)` or the wrapped asset
   * @param _router The router you are adding liquidity on behalf of
   */
  function addRouterLiquidityFor(
    uint256 _amount,
    address _local,
    address _router
  ) external payable nonReentrant whenNotPaused {
    _addLiquidityForRouter(_amount, _local, _router);
  }

  /**
   * @notice This is used by any router to increase their available liquidity for a given asset.
   * @dev The liquidity will be held in the local asset, which is the representation if you
   * are *not* on the canonical domain, and the canonical asset otherwise.
   * @param _amount - The amount of liquidity to add for the router
   * @param _local - The address of the asset you're adding liquidity for. If adding liquidity of the
   * native asset, routers may use `address(0)` or the wrapped asset
   */
  function addRouterLiquidity(uint256 _amount, address _local) external payable nonReentrant whenNotPaused {
    _addLiquidityForRouter(_amount, _local, msg.sender);
  }

  /**
   * @notice This is used by any router owner to decrease their available liquidity for a given asset.
   * @dev Using the `_canonical` information in the interface instead of the local asset to allow
   * routers to remove liquidity even if the asset is delisted
   * @param _canonical The canonical token information in plaintext
   * @param _amount - The amount of liquidity to remove for the router
   * native asset, routers may use `address(0)` or the wrapped asset
   * @param _to The address that will receive the liquidity being removed
   * @param _router The address of the router
   */
  function removeRouterLiquidityFor(
    TokenId memory _canonical,
    uint256 _amount,
    address payable _to,
    address _router
  ) external nonReentrant whenNotPaused {
    // Caller must be the router owner, if defined, else the router
    address owner = routerConfigs[_router].owner;
    address permissioned = owner == address(0) ? _router : owner;
    if (msg.sender != permissioned) revert RoutersManager__removeRouterLiquidityFor_notOwner();
    // Remove liquidity
    _removeLiquidityForRouter(_amount, _canonical, _to, _router);
  }

  /**
   * @notice This is used by any router to decrease their available liquidity for a given asset.
   * @dev Using the `_canonical` information in the interface instead of the local asset to allow
   * routers to remove liquidity even if the asset is delisted
   * @param _canonical The canonical token information in plaintext
   * @param _amount - The amount of liquidity to remove for the router
   * @param _to The address that will receive the liquidity being removed if no router recipient exists.
   */
  function removeRouterLiquidity(
    TokenId memory _canonical,
    uint256 _amount,
    address payable _to
  ) external nonReentrant whenNotPaused {
    _removeLiquidityForRouter(_amount, _canonical, _to, msg.sender);
  }

  // ============ Internal functions ============

  /**
   * @notice Sets the router recipient
   * @param _router The router to set the recipient for
   * @param _updated The recipient to set
   * @param _previous The existing recipient
   */
  function _setRouterRecipient(address _router, address _updated, address _previous) internal {
    // Check recipient is changing
    if (_previous == _updated) revert RoutersManager__setRouterRecipient_notNewRecipient();

    // Set new recipient
    routerConfigs[_router].recipient = _updated;

    // Emit event
    emit RouterRecipientSet(_router, _previous, _updated);
  }

  /**
   * @notice Sets the router owner
   * @param _router The router to set the owner for
   * @param _updated The owner to set
   * @param _previous The existing owner
   */
  function _setRouterOwner(address _router, address _updated, address _previous) internal {
    // Check owner is changing
    if (_previous == _updated) revert RoutersManager__setRouterOwner_noChange();

    // Set new owner
    routerConfigs[_router].owner = _updated;

    // Emit event
    emit RouterOwnerAccepted(_router, _previous, _updated);
  }

  /**
   * @notice Contains the logic to verify + increment a given routers liquidity
   * @dev The liquidity will be held in the local asset, which is the representation if you
   * are *not* on the canonical domain, and the canonical asset otherwise.
   * @param _amount - The amount of liquidity to add for the router
   * @param _local - The address of the bridge representation of the asset
   * @param _router - The router you are adding liquidity on behalf of
   */
  function _addLiquidityForRouter(uint256 _amount, address _local, address _router) internal {
    // Sanity check: router is sensible.
    if (_router == address(0)) revert RoutersManager__addLiquidityForRouter_routerEmpty();

    // Sanity check: nonzero amounts.
    if (_amount == 0) revert RoutersManager__addLiquidityForRouter_amountIsZero();

    // Get the canonical asset ID from the representation.
    // NOTE: not using `_getApprovedCanonicalId` because candidate can *only* be local

    uint32 canonicalDomain = representationToCanonical[_local].domain;
    bytes32 canonicalId = representationToCanonical[_local].id;

    if (canonicalDomain == 0 && canonicalId == bytes32(0)) {
      // Assume you are on the canonical domain, which does not update the above mapping
      // If this is an incorrect assumption, the approval should fail
      canonicalDomain = domain;
      canonicalId = TypeCasts.addressToBytes32(_local);
    }
    bytes32 key = calculateCanonicalHash(canonicalId, canonicalDomain);
    if (!tokenConfigs[key].approval) {
      revert RoutersManager__getApprovedCanonicalId_notAllowlisted();
    }

    // Sanity check: router is approved.
    if (!_isRouterAllowlistRemoved() && !getRouterApproval(_router)) {
      revert RoutersManager__addLiquidityForRouter_badRouter();
    }

    // Transfer funds to contract.
    _handleIncomingAsset(_local, _amount);

    // Update the router balances. Happens after pulling funds to account for
    // the fee on transfer tokens.
    routerBalances[_router][_local] += _amount;

    emit RouterLiquidityAdded({router: _router, local: _local, key: key, amount: _amount, caller: msg.sender});
  }

  /**
   * @notice This is used by any router owner to decrease their available liquidity for a given asset.
   * @param _amount - The amount of liquidity to remove for the router
   * @param _canonical The canonical token information in plaintext
   * @param _to The address that will receive the liquidity being removed
   * @param _router The address of the router
   */
  function _removeLiquidityForRouter(
    uint256 _amount,
    TokenId memory _canonical,
    address payable _to,
    address _router
  ) internal {
    // Transfer to specified recipient IF recipient not set.
    address recipient = getRouterRecipient(_router);
    recipient = recipient == address(0) ? _to : recipient;

    // Sanity check: to is sensible.
    if (recipient == address(0)) revert RoutersManager__removeRouterLiquidity_recipientEmpty();

    // Sanity check: nonzero amounts.
    if (_amount == 0) revert RoutersManager__removeRouterLiquidity_amountIsZero();

    bool onCanonical = _canonical.domain == domain;

    // Get the local asset from canonical
    // NOTE: allow getting unapproved assets to prevent lockup on approval status change
    // NOTE: not using `_getCanonicalTokenId` because candidate can *only* be local
    bytes32 key = calculateCanonicalHash(_canonical.id, _canonical.domain);
    address local = onCanonical ? TypeCasts.bytes32ToAddress(_canonical.id) : tokenConfigs[key].representation;

    // Get existing router balance.
    uint256 routerBalance = routerBalances[_router][local];

    // Sanity check: amount can be deducted for the router.
    if (routerBalance < _amount) revert RoutersManager__removeRouterLiquidity_insufficientFunds();

    // Update router balances.
    unchecked {
      routerBalances[_router][local] = routerBalance - _amount;
    }

    // Transfer from contract to specified `to` address.
    _handleOutgoingAsset(local, recipient, _amount);

    emit RouterLiquidityRemoved({
      router: _router,
      to: recipient,
      local: local,
      key: key,
      amount: _amount,
      caller: msg.sender
    });
  }

  /**
   * @notice Indicates if the router allowlist has been removed
   */
  function _isRouterAllowlistRemoved() internal view returns (bool) {
    return owner == address(0) || _routerAllowlistRemoved;
  }
}
