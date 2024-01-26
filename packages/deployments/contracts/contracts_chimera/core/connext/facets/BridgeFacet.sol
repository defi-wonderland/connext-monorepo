// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import {ExcessivelySafeCall} from "../../../shared/libraries/ExcessivelySafeCall.sol";
import {TypedMemView} from "../../../shared/libraries/TypedMemView.sol";
import {TypeCasts} from "../../../shared/libraries/TypeCasts.sol";

import {IOutbox} from "../../../messaging/interfaces/IOutbox.sol";

import {BaseConnextFacet} from "./BaseConnextFacet.sol";

import {AssetLogic} from "../libraries/AssetLogic.sol";
import {TransferData, DestinationTransferStatus, TokenConfig} from "../libraries/LibConnextStorage.sol";
import {BridgeMessage} from "../libraries/BridgeMessage.sol";
import {Constants} from "../libraries/Constants.sol";
import {TokenId} from "../libraries/TokenId.sol";

import {IXReceiver} from "../interfaces/IXReceiver.sol";

/**
 * @notice Defines the fields needed for an asset transfer
 * @param asset - The address of the asset
 * @param amount - The amount of the asset
 */
struct AssetTransfer {
  address asset;
  uint256 amount;
}

contract BridgeFacet is BaseConnextFacet {
  // ============ Libraries ============

  using TypedMemView for bytes;
  using TypedMemView for bytes29;
  using BridgeMessage for bytes29;
  using SafeERC20 for IERC20Metadata;

  // ========== Custom Errors ===========

  error BridgeFacet__xcall_nativeAssetNotSupported();
  error BridgeFacet__xcall_emptyTo();
  error BridgeFacet__execute_unapprovedSender();
  error BridgeFacet__execute_wrongDomain();
  error BridgeFacet__execute_notSupportedSequencer();
  error BridgeFacet__execute_invalidSequencerSignature();
  error BridgeFacet__execute_maxRoutersExceeded();
  error BridgeFacet__execute_notSupportedRouter();
  error BridgeFacet__execute_invalidRouterSignature();
  error BridgeFacet__execute_badFastLiquidityStatus();
  error BridgeFacet__execute_notReconciled();
  error BridgeFacet__execute_externalCallFailed();
  error BridgeFacet__excecute_insufficientGas();
  error BridgeFacet__mustHaveRemote_destinationNotSupported();

  // ============ Properties ============

  // ============ Events ============

  /**
   * @notice Emitted when `xcall` is called on the origin domain of a transfer.
   * @param transferId - The unique identifier of the crosschain transfer.
   * @param nonce - The bridge nonce of the transfer on the origin domain.
   * @param messageHash - The hash of the message bytes (containing all transfer info) that were bridged.
   * @param params - The `TransferData` provided to the function.
   * @param asset - The asset sent in with xcall
   * @param amount - The amount sent in with xcall
   */
  event XCalled(
    bytes32 indexed transferId,
    uint256 indexed nonce,
    bytes32 indexed messageHash,
    TransferData params,
    address asset,
    uint256 amount,
    bytes messageBody
  );

  /**
   * @notice Emitted when a transfer has its external data executed
   * @param transferId - The unique identifier of the crosschain transfer.
   * @param success - Whether calldata succeeded
   * @param returnData - Return bytes from the IXReceiver
   */
  event ExternalCalldataExecuted(bytes32 indexed transferId, bool success, bytes returnData);

  /**
   * @notice Emitted when `execute` is called on the destination domain of a transfer.
   * @dev `execute` may be called when providing fast liquidity or when processing a reconciled (slow) transfer.
   * @param transferId - The unique identifier of the crosschain transfer.
   * @param to - The recipient `TransferData.receiver` provided, created as indexed parameter.
   * @param asset - The asset the recipient is given or the external call is executed with. Should be the
   * adopted asset on that chain.
   * @param transferData - The `TransferData` provided to the function.
   * @param amount - The amount of transferring asset the recipient address receives or the external call is
   * executed with.
   * @param caller - The account that called the function.
   */
  event Executed(
    bytes32 indexed transferId,
    address indexed to,
    address indexed asset,
    TransferData transferData,
    uint256 amount,
    address caller
  );

  // ============ Public Functions: Bridge ==============

  function xcall(
    uint32 _destination,
    address _to,
    address _asset,
    address _delegate,
    uint256 _amount,
    bytes calldata _callData
  ) external payable nonXCallReentrant returns (bytes32) {
    // NOTE: Here, we fill in as much information as we can for the TransferData.
    // Some info is left blank and will be assigned in the internal `_xcall` function (e.g.
    // `bridgedAmt`, canonical info, etc).
    TransferData memory transferData = TransferData({
      status: DestinationTransferStatus.None,
      originDomain: s.domain,
      destinationDomain: _destination,
      reconcileDomain: _destination,
      sender: msg.sender,
      receiver: _to,
      delegate: _delegate,
      originAsset: _asset,
      bridgedAmt: _amount,
      callData: _callData,
      // The following values should be assigned in _xcall.
      nonce: 0,
      canonicalDomain: 0,
      canonicalId: bytes32(0),
      originAssetDecimals: 0,
      strategy: 0,
      strategyData: abi.encode(0),
      // The following values should be assigned in the destination / reconcile domain.
      destinationAsset: address(0),
      destinationAssetDecimals: 0,
      routers: new address[](0),
      routerSignatures: new bytes[](0),
      sequencer: address(0),
      sequencerSignature: abi.encode(0)
    });
    return _xcall(transferData, AssetTransfer(address(0), msg.value));
  }

  function xcall(
    uint32 _destination,
    address _to,
    address _asset,
    address _delegate,
    uint256 _amount,
    bytes calldata _callData,
    uint256 _relayerFee
  ) external nonXCallReentrant returns (bytes32) {
    // NOTE: Here, we fill in as much information as we can for the TransferData.
    // Some info is left blank and will be assigned in the internal `_xcall` function (e.g.
    // `bridgedAmt`, canonical info, etc).
    TransferData memory transferData = TransferData({
      status: DestinationTransferStatus.None,
      originDomain: s.domain,
      destinationDomain: _destination,
      reconcileDomain: _destination,
      sender: msg.sender,
      receiver: _to,
      delegate: _delegate,
      originAsset: _asset,
      bridgedAmt: _amount,
      callData: _callData,
      // The following values should be assigned in _xcall.
      nonce: 0,
      canonicalDomain: 0,
      canonicalId: bytes32(0),
      originAssetDecimals: 0,
      strategy: 0,
      strategyData: abi.encode(0),
      // The following values should be assigned in the destination / reconcile domain.
      destinationAsset: address(0),
      destinationAssetDecimals: 0,
      routers: new address[](0),
      routerSignatures: new bytes[](0),
      sequencer: address(0),
      sequencerSignature: abi.encode(0)
    });
    return _xcall(transferData, AssetTransfer(_asset, _relayerFee));
  }

  /**
   * @notice Called on a destination domain to disburse correct assets to end recipient and execute any included
   * calldata.
   *
   * @dev Can be called before or after `handle` [reconcile] is called (regarding the same transfer), depending on
   * whether the fast liquidity route (i.e. funds provided by routers) is being used for this transfer. As a result,
   * executed calldata (including properties like `originSender`) may or may not be verified depending on whether the
   * reconcile has been completed (i.e. the optimistic confirmation period has elapsed).
   *
   * @param _transferData - TransferData arguments.
   * @return bytes32 - The transfer ID of the crosschain transfer. Should match the xcall's transfer ID in order for
   * reconciliation to occur.
   */
  function execute(TransferData calldata _transferData) external nonReentrant whenNotPaused returns (bytes32) {
    (bytes32 transferId, DestinationTransferStatus status) = _executeSanityChecks(_transferData);

    DestinationTransferStatus updated = status == DestinationTransferStatus.Reconciled
      ? DestinationTransferStatus.Completed
      : DestinationTransferStatus.Executed;

    s.transferStatus[transferId] = updated;

    // Supply assets to target recipient. Use router liquidity when this is a fast transfer, or mint bridge tokens
    // when this is a slow transfer.
    address asset = _handleExecuteLiquidity(
      transferId,
      AssetLogic.calculateCanonicalHash(_transferData.canonicalId, _transferData.canonicalDomain),
      updated != DestinationTransferStatus.Completed,
      _transferData
    );

    // Execute the transaction using the designated calldata.
    _handleExecuteTransaction(_transferData, asset, transferId, updated == DestinationTransferStatus.Completed);

    // Emit event.
    emit Executed(transferId, _transferData.receiver, asset, _transferData, _transferData.bridgedAmt, msg.sender);

    return transferId;
  }

  // ============ Internal: Bridge ============

  /**
   * @notice Initiates a cross-chain transfer of funds and/or calldata
   *
   * @dev For ERC20 transfers, this contract must have approval to transfer the input (transacting) assets. The adopted
   * assets will be swapped for their local asset counterparts (i.e. bridgeable tokens) via the configured AMM if
   * necessary. In the event that the adopted assets *are* local bridge assets, no swap is needed. The local tokens will
   * then be sent via the bridge router. If the local assets are representational for an asset on another chain, we will
   * burn the tokens here. If the local assets are canonical (meaning that the adopted<>local asset pairing is native
   * to this chain), we will custody the tokens here.
   *
   * @param _transferData - The TransferData arguments.
   * @return bytes32 - The transfer ID of the newly created crosschain transfer.
   */
  function _xcall(
    TransferData memory _transferData,
    AssetTransfer memory _relayer
  ) internal whenNotPaused returns (bytes32) {
    // Sanity checks.
    bytes32 remoteInstance;
    {
      // Not native asset.
      // NOTE: We support using address(0) as an intuitive default if you are sending a 0-value
      // transfer. In that edge case, address(0) will not be registered as a supported asset, but should
      // pass the `isLocalOrigin` check
      if (_transferData.originAsset == address(0) && _transferData.bridgedAmt != 0) {
        revert BridgeFacet__xcall_nativeAssetNotSupported();
      }

      // Destination domain is supported.
      // NOTE: This check implicitly also checks that `_transferData.destinationDomain != s.domain`, because the index
      // `s.domain` of `s.remotes` should always be `bytes32(0)`.
      remoteInstance = _mustHaveRemote(_transferData.destinationDomain);

      // Recipient defined.
      if (_transferData.receiver == address(0)) {
        revert BridgeFacet__xcall_emptyTo();
      }
    }

    uint64 transferId;
    bytes32 transferHash;
    TokenId memory canonical;
    bool isCanonical;
    {
      // Check that the asset is supported.
      // NOTE: Above we check that you can only have `address(0)` as the input asset if this is a
      // 0-value transfer. Because 0-value transfers short-circuit all checks on mappings keyed on
      // hash(canonicalId, canonicalDomain), this is safe even when the address(0) asset is not
      // allowlisted.
      if (_transferData.originAsset != address(0)) {
        // Retrieve the canonical token information.
        bytes32 key;
        (canonical, key) = _getApprovedCanonicalId(_transferData.originAsset);

        // Get the token config.
        TokenConfig storage config = AssetLogic.getConfig(key);

        // Set boolean flag
        isCanonical = _transferData.originDomain == canonical.domain;

        // if (isCanonical) {
        //   _transferData.originAsset = TypeCasts.bytes32ToAddress(canonical.id);
        // }

        // Update TransferData to reflect the canonical token information.
        _transferData.canonicalDomain = canonical.domain;
        _transferData.canonicalId = canonical.id;
        _transferData.originAssetDecimals = config.adoptedDecimals;

        if (_transferData.bridgedAmt > 0) {
          // Transfer funds of input asset to the contract from the user.
          AssetLogic.handleIncomingAsset(_transferData.originAsset, _transferData.bridgedAmt);
        }
      }

      // Calculate the transfer ID and hash
      _transferData.nonce = s.nonce++;
      transferId = _originAndNonce(_transferData.originDomain, _transferData.nonce);
      transferHash = _calculateTransferHash(_transferData);

      // Store the transfer hash
      s.transferHashes[transferId] = transferHash;
    }

    // Handle the relayer fee.
    if (_relayer.amount > 0) {
      _bumpTransfer(transferId, _relayer.asset, _relayer.amount);
    }

    // Send the crosschain message.
    _sendMessageAndEmit(transferId, _transferData, remoteInstance);

    return transferId;
  }

  /**
   * @notice Holds the logic to recover the signer from an encoded payload.
   * @dev Will hash and convert to an eth signed message.
   * @param _signed The hash that was signed.
   * @param _sig The signature from which we will recover the signer.
   */
  function _recoverSignature(bytes32 _signed, bytes calldata _sig) internal pure returns (address) {
    // Recover
    return ECDSA.recover(ECDSA.toEthSignedMessageHash(_signed), _sig);
  }

  /**
   * @notice Performs some sanity checks for `execute`.
   * @dev Need this to prevent stack too deep.
   * @param _transferData TransferData that were passed in to the `execute` call.
   */
  function _executeSanityChecks(
    TransferData calldata _transferData
  ) private view returns (bytes32, DestinationTransferStatus) {
    // If the sender is not approved relayer, revert
    if (!s.approvedRelayers[msg.sender] && msg.sender != _transferData.delegate) {
      revert BridgeFacet__execute_unapprovedSender();
    }

    // If this is not the destination domain revert
    if (_transferData.destinationDomain != s.domain) {
      revert BridgeFacet__execute_wrongDomain();
    }

    // Path length refers to the number of facilitating routers. A transfer is considered 'multipath'
    // if multiple routers provide liquidity (in even 'shares') for it.
    uint256 pathLength = _transferData.routers.length;

    // Derive transfer ID based on given arguments.
    bytes32 transferId = _originAndNonce(_transferData.originDomain, _transferData.nonce);

    // Retrieve the reconciled record.
    DestinationTransferStatus status = s.transferStatus[transferId];

    if (pathLength != 0) {
      // Make sure number of routers is below the configured maximum.
      if (pathLength > s.maxRoutersPerTransfer) revert BridgeFacet__execute_maxRoutersExceeded();

      // Check to make sure the transfer has not been reconciled (no need for routers if the transfer is
      // already reconciled; i.e. if there are routers provided, the transfer must *not* be reconciled).
      if (status != DestinationTransferStatus.None) revert BridgeFacet__execute_badFastLiquidityStatus();

      // NOTE: The sequencer address may be empty and no signature needs to be provided in the case of the
      // slow liquidity route (i.e. no routers involved). Additionally, the sequencer does not need to be the
      // msg.sender.
      // Check to make sure the sequencer address provided is approved
      if (!s.approvedSequencers[_transferData.sequencer]) {
        revert BridgeFacet__execute_notSupportedSequencer();
      }
      // Check to make sure the sequencer provided did sign the transfer ID and router path provided.
      // NOTE: when caps are enforced, this signature also acts as protection from malicious routers looking
      // to block the network. routers could `execute` a fake transaction, and use up the rest of the `custodied`
      // bandwidth, causing future `execute`s to fail. this would also cause a break in the accounting, where the
      // `custodied` balance no longer tracks representation asset minting / burning
      if (
        _transferData.sequencer !=
        _recoverSignature(keccak256(abi.encode(transferId, _transferData.routers)), _transferData.sequencerSignature)
      ) {
        revert BridgeFacet__execute_invalidSequencerSignature();
      }

      // Hash the payload for which each router should have produced a signature.
      // Each router should have signed the `transferId` (which implicitly signs call params,
      // amount, and tokenId) as well as the `pathLength`, or the number of routers with which
      // they are splitting liquidity provision.
      bytes32 routerHash = keccak256(abi.encode(transferId, pathLength));

      for (uint256 i; i < pathLength; ) {
        // Make sure the router is approved, if applicable.
        // If router ownership is renounced (_RouterOwnershipRenounced() is true), then the router allowlist
        // no longer applies and we can skip this approval step.
        if (!_isRouterAllowlistRemoved() && !s.routerConfigs[_transferData.routers[i]].approved) {
          revert BridgeFacet__execute_notSupportedRouter();
        }

        // Validate the signature. We'll recover the signer's address using the expected payload and basic ECDSA
        // signature scheme recovery. The address for each signature must match the router's address.
        if (_transferData.routers[i] != _recoverSignature(routerHash, _transferData.routerSignatures[i])) {
          revert BridgeFacet__execute_invalidRouterSignature();
        }

        unchecked {
          ++i;
        }
      }
    } else {
      // If there are no routers for this transfer, this `execute` must be a slow liquidity route; in which
      // case, we must make sure the transfer's been reconciled.
      if (status != DestinationTransferStatus.Reconciled) revert BridgeFacet__execute_notReconciled();
    }

    return (transferId, status);
  }

  /**
   * @notice Calculates fast transfer amount.
   * @param _amount Transfer amount
   * @param _numerator Numerator
   * @param _denominator Denominator
   */
  function _muldiv(uint256 _amount, uint256 _numerator, uint256 _denominator) private pure returns (uint256) {
    return (_amount * _numerator) / _denominator;
  }

  /**
   * @notice Execute liquidity process used when calling `execute`.
   * @dev Will revert with underflow if any router in the path has insufficient liquidity to provide
   * for the transfer.
   * @dev Need this to prevent stack too deep.
   */
  function _handleExecuteLiquidity(
    bytes32 _transferId,
    bytes32 _key,
    bool _isFast,
    TransferData calldata _transferData
  ) private returns (address) {
    // Save the addresses of all routers providing liquidity for this transfer.
    s.routedTransfers[_transferId] = _transferData.routers;

    // Get the adopted asset contract address.
    address adopted;
    if (_transferData.canonicalDomain != 0) {
      adopted = _getAdoptedAsset(_key, _transferData.canonicalId, _transferData.canonicalDomain);
    }

    // If this is a zero-value transfer, short-circuit remaining logic.
    if (_transferData.bridgedAmt == 0) {
      return adopted;
    }

    uint256 toSwap = _transferData.bridgedAmt;
    // If this is a fast liquidity path, we should handle deducting from applicable routers' liquidity.
    // If this is a slow liquidity path, the transfer must have been reconciled (if we've reached this point),
    // and the funds would have been custodied in this contract. The exact custodied amount is untracked in state
    // (since the amount is hashed in the transfer ID itself) - thus, no updates are required.
    if (_isFast) {
      uint256 pathLen = _transferData.routers.length;

      // Calculate amount that routers will provide with the fast-liquidity fee deducted.
      toSwap = _muldiv(_transferData.bridgedAmt, s.LIQUIDITY_FEE_NUMERATOR, Constants.BPS_FEE_DENOMINATOR);

      if (pathLen == 1) {
        // Decrement the router's liquidity.
        s.routerBalances[_transferData.routers[0]][adopted] -= toSwap;
      } else {
        // For each router, assert they are approved, and deduct liquidity.
        uint256 routerAmount = toSwap / pathLen;
        for (uint256 i; i < pathLen - 1; ) {
          // Decrement router's liquidity.
          // NOTE: If any router in the path has insufficient liquidity, this will revert with an underflow error.
          s.routerBalances[_transferData.routers[i]][adopted] -= routerAmount;

          unchecked {
            ++i;
          }
        }
        // The last router in the multipath will sweep the remaining balance to account for remainder dust.
        uint256 toSweep = routerAmount + (toSwap % pathLen);
        s.routerBalances[_transferData.routers[pathLen - 1]][adopted] -= toSweep;
      }
    }

    return adopted;
  }

  /**
   * @notice Process the transfer, and calldata if needed, when calling `execute`
   * @dev Need this to prevent stack too deep
   */
  function _handleExecuteTransaction(
    TransferData calldata _transferData,
    address _asset, // adopted (or local if specified)
    bytes32 _transferId,
    bool _reconciled
  ) private returns (uint256) {
    // transfer funds to recipient
    AssetLogic.handleOutgoingAsset(_asset, _transferData.receiver, _transferData.bridgedAmt);

    // execute the calldata
    _executeCalldata(_transferId, _asset, _reconciled, _transferData);

    return _transferData.bridgedAmt;
  }

  /**
   * @notice Executes external calldata.
   * 
   * @dev Once a transfer is reconciled (i.e. data is authenticated), external calls will
   * fail gracefully. This means errors will be emitted in an event, but the function itself
   * will not revert.

   * In the case where a transaction is *not* reconciled (i.e. data is unauthenticated), this
   * external call will fail loudly. This allows all functions that rely on authenticated data
   * (using a specific check on the origin sender), to be forced into the slow path for
   * execution to succeed.
   * 
   */
  function _executeCalldata(
    bytes32 _transferId,
    address _asset,
    bool _reconciled,
    TransferData calldata _transferData
  ) internal {
    // execute the calldata
    if (keccak256(_transferData.callData) == Constants.EMPTY_HASH) {
      // no call data, return amount out
      return;
    }

    (bool success, bytes memory returnData) = ExcessivelySafeCall.excessivelySafeCall(
      _transferData.receiver,
      gasleft() - Constants.EXECUTE_CALLDATA_RESERVE_GAS,
      0, // native asset value (always 0)
      Constants.DEFAULT_COPY_BYTES, // only copy 256 bytes back as calldata
      abi.encodeWithSelector(
        IXReceiver.xReceive.selector,
        _transferId,
        _transferData.bridgedAmt,
        _asset,
        _reconciled ? _transferData.originSender : address(0), // use passed in value iff authenticated
        _transferData.originDomain,
        _transferData.callData
      )
    );

    if (!_reconciled && !success) {
      // See above devnote, reverts if unsuccessful on fast path
      revert BridgeFacet__execute_externalCallFailed();
    }

    emit ExternalCalldataExecuted(_transferId, success, returnData);
  }

  // ============ Internal: Send & Emit Xcalled============

  /**
   * @notice Format and send transfer message to a remote chain.
   *
   * @param _transferId Unique identifier for the transfer.
   * @param _transferData The TransferData.
   * @param _connextion The connext instance on the destination domain.
   */
  function _sendMessageAndEmit(bytes32 _transferId, TransferData memory _transferData, bytes32 _connextion) private {
    bytes memory _messageBody = abi.encodePacked(
      _transferData.canonicalDomain,
      _transferData.canonicalId,
      BridgeMessage.Types.Transfer,
      _transferData.bridgedAmt,
      _transferId
    );

    // Send message to destination chain bridge router.
    // return message hash and unhashed body
    (bytes32 messageHash, bytes memory messageBody) = IOutbox(s.xAppConnectionManager.home()).dispatch(
      _transferData.destinationDomain,
      _connextion,
      _messageBody
    );

    // emit event
    emit XCalled(
      _transferId,
      _transferData.nonce,
      messageHash,
      _transferData,
      _transferData.originAsset,
      _transferData.bridgedAmt,
      messageBody
    );
  }

  /**
   * @notice Assert that the given domain has a xApp Router registered and return its address
   * @param _domain The domain of the chain for which to get the xApp Router
   * @return _remote The address of the remote xApp Router on _domain
   */
  function _mustHaveRemote(uint32 _domain) internal view returns (bytes32 _remote) {
    _remote = s.remotes[_domain];
    if (_remote == bytes32(0)) {
      revert BridgeFacet__mustHaveRemote_destinationNotSupported();
    }
  }
}
