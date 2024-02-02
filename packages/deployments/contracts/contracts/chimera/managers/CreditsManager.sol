// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {BaseManager} from './BaseManager.sol';
import {BridgeMessage} from '../libraries/BridgeMessage.sol';
import {IOutbox} from '../../messaging/interfaces/IOutbox.sol';
import {IBridgeToken} from '../interfaces/IBridgeToken.sol';

import {TransferInfo, TokenId} from '../libraries/LibConnextStorage.sol';

contract CreditsManager is BaseManager {
  // ============ Events ============

  /**
   * @notice Emitted when `xcall` is called on the origin domain of a transfer.
   * @param transferId - The unique identifier of the crosschain transfer.
   * @param nonce - The bridge nonce of the transfer on the origin domain.
   * @param messageHash - The hash of the message bytes (containing all transfer info) that were bridged.
   * @param params - The `TransferInfo` provided to the function.
   * @param asset - The asset sent in with xcall
   * @param amount - The amount sent in with xcall
   * @param local - The local asset that is controlled by the bridge and can be burned/minted
   */
  event XCalled(
    bytes32 indexed transferId,
    uint256 indexed nonce,
    bytes32 indexed messageHash,
    TransferInfo params,
    address asset,
    uint256 amount,
    address local,
    bytes messageBody
  );

  // ============ Internal: Send & Emit Xcalled============
  /**
   * @notice Format and send transfer message to a remote chain.
   *
   * @param _transferId Unique identifier for the transfer.
   * @param _params The TransferInfo.
   * @param _connextion The connext instance on the destination domain.
   * @param _canonical The canonical token ID/domain info.
   * @param _local The local token address.
   * @param _amount The token amount.
   * @param _isCanonical Whether or not the local token is the canonical asset (i.e. this is the token's
   * "home" chain).
   */
  function _sendMessageAndEmit(
    bytes32 _transferId,
    TransferInfo memory _params,
    address _asset,
    uint256 _amount,
    bytes32 _connextion,
    TokenId memory _canonical,
    address _local,
    bool _isCanonical
  ) private {
    // Remove tokens from circulation on this chain if applicable.
    uint256 bridgedAmt = _params.bridgedAmt;
    if (bridgedAmt > 0) {
      if (!_isCanonical) {
        // If the token originates on a remote chain, burn the representational tokens on this chain.
        IBridgeToken(_local).burn(address(this), bridgedAmt);
      }
      // IFF the token IS the canonical token (i.e. originates on this chain), we lock the input tokens in escrow
      // in this contract, as an equal amount of representational assets will be minted on the destination chain.
      // NOTE: The tokens should be in the contract already at this point from xcall.
    }

    bytes memory _messageBody =
    // solhint-disable-next-line func-named-parameters
     abi.encodePacked(_canonical.domain, _canonical.id, BridgeMessage.Types.Transfer, bridgedAmt, _transferId);

    // Send message to destination chain bridge router.
    // return message hash and unhashed body
    (bytes32 messageHash, bytes memory messageBody) =
      IOutbox(xAppConnectionManager.home()).dispatch(_params.destinationDomain, _connextion, _messageBody);

    // emit event
    emit XCalled({
      transferId: _transferId,
      nonce: _params.nonce,
      messageHash: messageHash,
      params: _params,
      asset: _asset,
      amount: _amount,
      local: _local,
      messageBody: messageBody
    });
  }
}
