// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {IERC20Metadata} from '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';
import {ECDSA} from '@openzeppelin/contracts/utils/cryptography/ECDSA.sol';
import {Address} from '@openzeppelin/contracts/utils/Address.sol';

import {ExcessivelySafeCall} from '../shared/libraries/ExcessivelySafeCall.sol';
import {TypedMemView} from '../shared/libraries/TypedMemView.sol';
import {TypeCasts} from '../shared/libraries/TypeCasts.sol';

import {Constants} from './libraries/Constants.sol';

import {IXReceiver} from './interfaces/IXReceiver.sol';

import {IConnextCore} from './interfaces/IConnextCore.sol';
import {AssetsManager} from './managers/AssetsManager.sol';
import {ProtocolManager} from './managers/ProtocolManager.sol';
import {RolesManager} from './managers/RolesManager.sol';
import {RoutersManager} from './managers/RoutersManager.sol';
import {CreditsManager} from './managers/CreditsManager.sol';

// Core contract
contract ConnextCore is IConnextCore, ProtocolManager, RolesManager, AssetsManager, RoutersManager, CreditsManager {
  // ============ Libraries ============

  using TypedMemView for bytes;
  using TypedMemView for bytes29;
  using SafeERC20 for IERC20Metadata;

  // ========== Custom Errors ===========

  error Connext__xcall_nativeAssetNotSupported();
  error Connext__xcall_emptyTo();
  error Connext__execute_unapprovedSender();
  error Connext__execute_wrongDomain();
  error Connext__execute_notSupportedSequencer();
  error Connext__execute_invalidSequencerSignature();
  error Connext__execute_maxRoutersExceeded();
  error Connext__execute_notSupportedRouter();
  error Connext__execute_invalidRouterSignature();
  error Connext__execute_badFastLiquidityStatus();
  error Connext__execute_notReconciled();
  error Connext__execute_externalCallFailed();
  error Connext__excecute_insufficientGas();
  error Connext__bumpTransfer_valueIsZero();
  error Connext__bumpTransfer_noRelayerVault();
  error Connext__mustHaveRemote_destinationNotSupported();

  // ============ Properties ============

  // ============ Events ============

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
   * @param to - The recipient `TransferInfo.to` provided, created as indexed parameter.
   * @param asset - The asset the recipient is given or the external call is executed with.
   * It was either supplied by the router for a fast-liquidity transfer or by the bridge in a reconciled (slow) transfer.
   * @param args - The `ExecuteArgs` provided to the function.
   * @param amount - The amount of transferring asset the recipient address receives or the external call is
   * executed with.
   * @param caller - The account that called the function.
   */
  event Executed(
    bytes32 indexed transferId,
    address indexed to,
    address indexed asset,
    ExecuteArgs args,
    uint256 amount,
    address caller
  );

  /**
   * @notice Emitted when `_bumpTransfer` is called by an user on the origin domain both in
   * `xcall` and `bumpTransfer`
   * @param transferId - The unique identifier of the crosschain transaction
   * @param increase - The additional amount fees increased by
   * @param asset - The asset the fee was increased with
   * @param caller - The account that called the function
   */
  event TransferRelayerFeesIncreased(bytes32 indexed transferId, uint256 increase, address asset, address caller);

  // ============ Public Functions: Bridge ==============
  function xcall(
    uint32 _destination,
    address _to,
    address _asset,
    address, // _delegate
    uint256 _amount,
    uint256, // _slippage
    bytes calldata _callData
  ) external payable nonXCallReentrant returns (bytes32) {
    // NOTE: Here, we fill in as much information as we can for the TransferInfo.
    // Some info is left blank and will be assigned in the internal `_xcall` function (e.g.
    // `normalizedIn`, `bridgedAmt`, canonical info, etc).
    TransferInfo memory params = TransferInfo({
      to: _to,
      callData: _callData,
      originDomain: domain,
      destinationDomain: _destination,
      originSender: msg.sender,
      // The following values should be assigned in _xcall.
      nonce: 0,
      canonicalDomain: 0,
      bridgedAmt: 0,
      normalizedIn: 0,
      canonicalId: bytes32(0)
    });
    return
      _xcall({_params: params, _asset: _asset, _amount: _amount, _relayerFeeAsset: address(0), _relayerFee: msg.value});
  }

  function xcall(
    uint32 _destination,
    address _to,
    address _asset,
    address, // _delegate
    uint256 _amount,
    uint256, // _slippage
    bytes calldata _callData,
    uint256 _relayerFee
  ) external nonXCallReentrant returns (bytes32) {
    // NOTE: Here, we fill in as much information as we can for the TransferInfo.
    // Some info is left blank and will be assigned in the internal `_xcall` function (e.g.
    // `normalizedIn`, `bridgedAmt`, canonical info, etc).
    TransferInfo memory params = TransferInfo({
      to: _to,
      callData: _callData,
      originDomain: domain,
      destinationDomain: _destination,
      originSender: msg.sender,
      // The following values should be assigned in _xcall.
      nonce: 0,
      canonicalDomain: 0,
      bridgedAmt: 0,
      normalizedIn: 0,
      canonicalId: bytes32(0)
    });
    return
      _xcall({_params: params, _asset: _asset, _amount: _amount, _relayerFeeAsset: _asset, _relayerFee: _relayerFee});
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
   * @param _args - ExecuteArgs arguments.
   * @return bytes32 - The transfer ID of the crosschain transfer. Should match the xcall's transfer ID in order for
   * reconciliation to occur.
   */
  function execute(ExecuteArgs calldata _args) external nonReentrant whenNotPaused returns (bytes32) {
    (bytes32 transferId, TransferStatus status) = _executeSanityChecks(_args);

    TransferStatus updated = status == TransferStatus.Reconciled ? TransferStatus.Completed : TransferStatus.Executed;

    transferStatus[transferId] = updated;

    // Supply assets to target recipient. Use router liquidity when this is a fast transfer, or mint bridge tokens
    // when this is a slow transfer.
    (uint256 amountOut, address asset) = _handleExecuteLiquidity(
      transferId,
      calculateCanonicalHash(_args.params.canonicalId, _args.params.canonicalDomain),
      updated != TransferStatus.Completed,
      _args
    );

    // Execute the transaction using the designated calldata.
    uint256 amount = _handleExecuteTransaction({
      _args: _args,
      _amountOut: amountOut,
      _asset: asset,
      _transferId: transferId,
      _reconciled: updated == TransferStatus.Completed
    });

    // Emit event.
    emit Executed({
      transferId: transferId,
      to: _args.params.to,
      asset: asset,
      args: _args,
      amount: amount,
      caller: msg.sender
    });

    return transferId;
  }

  /**
   * @notice Anyone can call this function on the origin domain to increase the relayer fee for a transfer.
   * @param _transferId - The unique identifier of the crosschain transaction
   */
  function bumpTransfer(bytes32 _transferId) external payable nonReentrant whenNotPaused {
    if (msg.value == 0) revert Connext__bumpTransfer_valueIsZero();
    _bumpTransfer(_transferId, address(0), msg.value);
  }

  /**
   * @notice Anyone can call this function on the origin domain t o increase the relayer fee for
   * a given transfer using a specific asset.
   * @param _transferId - The unique identifier of the crosschain transaction
   * @param _relayerFeeAsset - The asset you are bumping fee with
   * @param _relayerFee - The amount you want to bump transfer fee with
   */
  function bumpTransfer(
    bytes32 _transferId,
    address _relayerFeeAsset,
    uint256 _relayerFee
  ) external nonReentrant whenNotPaused {
    /*     if (_relayerFee == 0) revert Connext__bumpTransfer_valueIsZero();
    // check that the asset is whitelisted (the following reverts if asset
    // is not approved)
    _getApprovedCanonicalId(_relayerFeeAsset);
    // handle transferring asset to the relayer fee vault
    _bumpTransfer(_transferId, _relayerFeeAsset, _relayerFee); */
  }

  // ============ Internal: Bridge ============

  /**
   * @notice Initiates a cross-chain transfer of funds and/or calldata
   *
   * @dev For ERC20 transfers, this contract must have approval to transfer the input (transacting) assets.
   *
   * @param _params - The TransferInfo arguments.
   * @param _asset - The address of the asset
   * @param _amount - The amount of the asset
   * @param _relayerFeeAsset - The address of the relayer fee asset
   * @param _relayerFee - The amount of the relayer fee
   * @return bytes32 - The transfer ID of the newly created crosschain transfer.
   */
  function _xcall(
    TransferInfo memory _params,
    address _asset,
    uint256 _amount,
    address _relayerFeeAsset,
    uint256 _relayerFee
  ) internal whenNotPaused returns (bytes32) {
    /*  // Sanity checks.
    bytes32 remoteInstance;
    {
      // Not native asset.
      // NOTE: We support using address(0) as an intuitive default if you are sending a 0-value
      // transfer. In that edge case, address(0) will not be registered as a supported asset.
      if (_asset == address(0) && _amount != 0) {
        revert Connext__xcall_nativeAssetNotSupported();
      }

      // Destination domain is supported.
      // NOTE: This check implicitly also checks that `_params.destinationDomain != domain`, because the index
      // `s.domain` of `s.remotes` should always be `bytes32(0)`.
      remoteInstance = _mustHaveRemote(_params.destinationDomain);

      // Recipient defined.
      if (_params.to == address(0)) {
        revert Connext__xcall_emptyTo();
      }
    }

    bytes32 transferId;
    TokenId memory canonical;
    bool isCanonical;
    {
      // Check that the asset is supported.
      // NOTE: Above we check that you can only have `address(0)` as the input asset if this is a
      // 0-value transfer. Because 0-value transfers short-circuit all checks on mappings keyed on
      // hash(canonicalId, canonicalDomain), this is safe even when the address(0) asset is not
      // allowlisted.
      if (_asset != address(0)) {
        // Retrieve the canonical token information.
        bytes32 key;
        (canonical, key) = _getApprovedCanonicalId(_asset);

        // Get the token config.
        TokenConfig storage config = _getConfig(key);

        // Set boolean flag
        isCanonical = _params.originDomain == canonical.domain;

        // Update TransferInfo to reflect the canonical token information.
        _params.canonicalDomain = canonical.domain;
        _params.canonicalId = canonical.id;

        if (_amount > 0) {
          // Transfer funds of input asset to the contract from the user.
          AssetLogic.handleIncomingAsset(_asset, _amount);

          _params.bridgedAmt = _amount;

          // Get the normalized amount in (amount sent in by user in 18 decimals).
          _params.normalizedIn = AssetLogic.normalizeDecimals(
            config.assetDecimals,
            Constants.DEFAULT_NORMALIZED_DECIMALS,
            _amount
          );
        }
      }

      // Calculate the transfer ID.
      _params.nonce = nonce++;
      transferId = _calculateTransferId(_params);
    }

    // Handle the relayer fee.
    if (_relayerFee > 0) {
      _bumpTransfer(transferId, _relayerFeeAsset, _relayerFee);
    }

    // Send the crosschain message.
    _sendMessageAndEmit(
      transferId,
      _params,
      _asset,
      _amount,
      remoteInstance,
      canonical
    );

    return transferId; */
  }

  /**
   * @notice An internal function to handle the bumping of transfers
   * @param _transferId - The unique identifier of the crosschain transaction
   * @param _relayerFeeAsset - The asset you are bumping fee with
   * @param _relayerFee - The amount you want to bump transfer fee with
   */
  function _bumpTransfer(bytes32 _transferId, address _relayerFeeAsset, uint256 _relayerFee) internal {
    address relayerVault = relayerFeeVault;
    if (relayerVault == address(0)) revert Connext__bumpTransfer_noRelayerVault();
    if (_relayerFeeAsset == address(0)) {
      Address.sendValue(payable(relayerVault), _relayerFee);
    } else {
      // Pull funds from user to this contract
      // NOTE: could transfer to `relayerFeeVault`, but that would be unintuitive for user
      // approvals
      _handleIncomingAsset(_relayerFeeAsset, _relayerFee);

      // Transfer asset to relayerVault.
      _handleOutgoingAsset(_relayerFeeAsset, relayerVault, _relayerFee);
    }

    emit TransferRelayerFeesIncreased(_transferId, _relayerFee, _relayerFeeAsset, msg.sender);
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
   * @param _args ExecuteArgs that were passed in to the `execute` call.
   */
  function _executeSanityChecks(ExecuteArgs calldata _args) private view returns (bytes32, TransferStatus) {
    // // If the sender is not approved relayer, revert
    // if (!approvedRelayers[msg.sender]) {
    //   revert Connext__execute_unapprovedSender();
    // }
    // // If this is not the destination domain revert
    // if (_args.params.destinationDomain != domain) {
    //   revert Connext__execute_wrongDomain();
    // }
    // // Path length refers to the number of facilitating routers. A transfer is considered 'multipath'
    // // if multiple routers provide liquidity (in even 'shares') for it.
    // uint256 pathLength = _args.routers.length;
    // // Derive transfer ID based on given arguments.
    // bytes32 transferId = _calculateTransferId(_args.params);
    // // Retrieve the reconciled record.
    // TransferStatus status = transferStatus[transferId];

    // if (pathLength != 0) {
    //   // Make sure number of routers is below the configured maximum.
    //   if (pathLength > maxRoutersPerTransfer) revert Connext__execute_maxRoutersExceeded();
    //   // Check to make sure the transfer has not been reconciled (no need for routers if the transfer is
    //   // already reconciled; i.e. if there are routers provided, the transfer must *not* be reconciled).
    //   if (status != TransferStatus.None) revert Connext__execute_badFastLiquidityStatus();

    //   // NOTE: The sequencer address may be empty and no signature needs to be provided in the case of the
    //   // slow liquidity route (i.e. no routers involved). Additionally, the sequencer does not need to be the
    //   // msg.sender.
    //   // Check to make sure the sequencer address provided is approved
    //   if (!approvedSequencers[_args.sequencer]) {
    //     revert Connext__execute_notSupportedSequencer();
    //   }
    //   // Check to make sure the sequencer provided did sign the transfer ID and router path provided.
    //   if (
    //     _args.sequencer != _recoverSignature(keccak256(abi.encode(transferId, _args.routers)), _args.sequencerSignature)
    //   ) {
    //     revert Connext__execute_invalidSequencerSignature();
    //   }
    //   // Hash the payload for which each router should have produced a signature.
    //   // Each router should have signed the `transferId` (which implicitly signs call params,
    //   // amount, and tokenId) as well as the `pathLength`, or the number of routers with which
    //   // they are splitting liquidity provision.
    //   bytes32 routerHash = keccak256(abi.encode(transferId, pathLength));
    //   for (uint256 i; i < pathLength; ) {
    //     // Make sure the router is approved, if applicable.
    //     // If router ownership is renounced (_RouterOwnershipRenounced() is true), then the router allowlist
    //     // no longer applies and we can skip this approval step.
    //     if (!_isRouterAllowlistRemoved() && !routerConfigs[_args.routers[i]].approved) {
    //       revert Connext__execute_notSupportedRouter();
    //     }
    //     // Validate the signature. We'll recover the signer's address using the expected payload and basic ECDSA
    //     // signature scheme recovery. The address for each signature must match the router's address.
    //     if (_args.routers[i] != _recoverSignature(routerHash, _args.routerSignatures[i])) {
    //       revert Connext__execute_invalidRouterSignature();
    //     }
    //     unchecked {
    //       ++i;
    //     }
    //   }
    // } else {
    //   // If there are no routers for this transfer, this `execute` must be a slow liquidity route; in which
    //   // case, we must make sure the transfer's been reconciled.
    //   if (status != TransferStatus.Reconciled) revert Connext__execute_notReconciled();
    // }
    // return (transferId, status);
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
    ExecuteArgs calldata _args
  ) private returns (uint256, address) {
    // // Save the addresses of all routers providing liquidity for this transfer.
    // routedTransfers[_transferId] = _args.routers;

    // // Get the asset contract address.
    // address asset;
    // if (_args.params.canonicalDomain != 0) {
    //   asset = _getAsset(_key, _args.params.canonicalId, _args.params.canonicalDomain);
    // }
    // // If this is a zero-value transfer, short-circuit remaining logic.
    // if (_args.params.bridgedAmt == 0) {
    //   return (0, asset);
    // }
    // // If this is a fast liquidity path, we should handle deducting from applicable routers' liquidity.
    // // If this is a slow liquidity path, the transfer must have been reconciled (if we've reached this point),
    // // and the funds would have been custodied in this contract. The exact custodied amount is untracked in state
    // // (since the amount is hashed in the transfer ID itself) - thus, no updates are required.
    // if (_isFast) {
    //   uint256 pathLen = _args.routers.length;
    //   // Calculate amount that routers will provide with the fast-liquidity fee deducted.
    //   uint256 toTransfer = _muldiv(_args.params.bridgedAmt, LIQUIDITY_FEE_NUMERATOR, Constants.BPS_FEE_DENOMINATOR);

    //   if (pathLen == 1) {
    //     // Decrement the router's liquidity.
    //     // NOTE: If the router has insufficient liquidity, this will revert with an underflow error.
    //     routerBalances[_args.routers[0]][asset] -= toTransfer;
    //   } else {
    //     // For each router, assert they are approved, and deduct liquidity.
    //     uint256 routerAmount = toTransfer / pathLen;
    //     for (uint256 i; i < pathLen - 1; ) {
    //       // Decrement router's liquidity.
    //       // NOTE: If any router in the path has insufficient liquidity, this will revert with an underflow error.
    //       routerBalances[_args.routers[i]][asset] -= routerAmount;

    //       unchecked {
    //         ++i;
    //       }
    //     }
    //     // The last router in the multipath will sweep the remaining balance to account for remainder dust.
    //     uint256 toSweep = routerAmount + (toTransfer % pathLen);
    //     routerBalances[_args.routers[pathLen - 1]][asset] -= toSweep;
    //   }
    // }

    // return (amount, asset);
  }

  /**
   * @notice Process the transfer, and calldata if needed, when calling `execute`
   * @dev Need this to prevent stack too deep
   */
  function _handleExecuteTransaction(
    ExecuteArgs calldata _args,
    uint256 _amountOut,
    address _asset,
    bytes32 _transferId,
    bool _reconciled
  ) private returns (uint256) {
    // transfer funds to recipient
    _handleOutgoingAsset(_asset, _args.params.to, _amountOut);

    // execute the calldata
    _executeCalldata({
      _transferId: _transferId,
      _amount: _amountOut,
      _asset: _asset,
      _reconciled: _reconciled,
      _params: _args.params
    });

    return _amountOut;
  }

  /**
   * @notice Executes external calldata.
   *
   * @dev Once a transfer is reconciled (i.e. data is authenticated), external calls will
   * fail gracefully. This means errors will be emitted in an event, but the function itself
   * will not revert.
   *
   * In the case where a transaction is *not* reconciled (i.e. data is unauthenticated), this
   * external call will fail loudly. This allows all functions that rely on authenticated data
   * (using a specific check on the origin sender), to be forced into the slow path for
   * execution to succeed.
   *
   */
  function _executeCalldata(
    bytes32 _transferId,
    uint256 _amount,
    address _asset,
    bool _reconciled,
    TransferInfo calldata _params
  ) internal {
    // execute the calldata
    if (keccak256(_params.callData) == Constants.EMPTY_HASH) {
      // no call data, return amount out
      return;
    }

    /*
  address _target,
    uint256 _gas,
    uint256 _value,
    uint16 _maxCopy,
    bytes memory _calldata
    */
    (bool success, bytes memory returnData) = ExcessivelySafeCall.excessivelySafeCall({
      _target: _params.to,
      _gas: gasleft() - Constants.EXECUTE_CALLDATA_RESERVE_GAS,
      _value: 0, // native asset value (always 0)
      _maxCopy: Constants.DEFAULT_COPY_BYTES, // only copy 256 bytes back as calldata
      // solhint-disable-next-line func-named-parameters
      _calldata: abi.encodeWithSelector(
        IXReceiver.xReceive.selector,
        _transferId,
        _amount,
        _asset,
        _reconciled ? _params.originSender : address(0), // use passed in value iff authenticated
        _params.originDomain,
        _params.callData
        )
    });

    if (!_reconciled && !success) {
      // See above devnote, reverts if unsuccessful on fast path
      revert Connext__execute_externalCallFailed();
    }

    emit ExternalCalldataExecuted(_transferId, success, returnData);
  }

  /**
   * @notice Assert that the given domain has a xApp Router registered and return its address
   * @param _domain The domain of the chain for which to get the xApp Router
   * @return _remote The address of the remote xApp Router on _domain
   */
  function _mustHaveRemote(uint32 _domain) internal view returns (bytes32 _remote) {
    _remote = remotes[_domain];
    if (_remote == bytes32(0)) {
      revert Connext__mustHaveRemote_destinationNotSupported();
    }
  }

  /**
   * @notice Calculates a transferId
   */
  function _calculateTransferId(TransferInfo memory _params) internal pure returns (bytes32) {
    return keccak256(abi.encode(_params));
  }
}
