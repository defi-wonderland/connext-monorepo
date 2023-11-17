// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.17;

import {BaseScroll} from "./BaseScroll.sol";
import {Connector} from "../Connector.sol";
import {SpokeConnector} from "../SpokeConnector.sol";
import {ProposedOwnable} from "../../../../contracts/shared/ProposedOwnable.sol";
import {WatcherClient} from "../../WatcherClient.sol";
import {IL2ScrollMessenger} from "../../interfaces/ambs/scroll/IL2ScrollMessenger.sol";

/**
 * @title ScrollSpokeConnector
 * @notice Scroll Spoke Connector contract in charge of sending messages to the L1 Scroll Hub Connector through the
 * L2 Scroll Messenger, and receiving messages from the L1 Scroll Hub Connector through the L2 Scroll Messenger
 */
contract ScrollSpokeConnector is SpokeConnector, BaseScroll {
  /**
   * @notice Thrown when the message length is not 32 bytes
   */
  error ScrollSpokeConnector_LengthIsNot32();
  /**
   * @notice Thrown when the origin sender of the cross domain message is not the mirror connector
   */
  error ScrollSpokeConnector_OriginSenderIsNotMirror();

  /**
   * @notice L2 Scroll Messenger
   */
  IL2ScrollMessenger public immutable L2_SCROLL_MESSENGER;

  /**
   * @notice Creates a new ScrollSpokeConnector instance
   * @param _domain L2 domain
   * @param _mirrorDomain L1 domain
   * @param _amb Arbitrary Message Bridge address
   * @param _rootManager Root manager address
   * @param _mirrorConnector Mirror connector address
   * @param _processGas The gas costs used in `handle` to ensure meaningful state changes can occur (minimum gas needed
   * to handle transaction)
   * @param _reserveGas The gas costs reserved when `handle` is called to ensure failures are handled.
   * @param _delayBlocks The delay for the validation period for incoming messages in blocks.
   * @param _merkle Merkle tree manager address
   * @param _watcherManager Watcher manager address
   * @param _gasCap Gas limit to be provided on L1 cross domain message execution
   */
  constructor(
    uint32 _domain,
    uint32 _mirrorDomain,
    address _amb,
    address _rootManager,
    address _mirrorConnector,
    uint256 _processGas,
    uint256 _reserveGas,
    uint256 _delayBlocks,
    address _merkle,
    address _watcherManager,
    uint256 _gasCap
  )
    SpokeConnector(
      _domain,
      _mirrorDomain,
      _amb,
      _rootManager,
      _mirrorConnector,
      _processGas,
      _reserveGas,
      _delayBlocks,
      _merkle,
      _watcherManager
    )
    BaseScroll(_gasCap)
  {
    L2_SCROLL_MESSENGER = IL2ScrollMessenger(_amb);
  }

  /**
   * @notice Checks that the message length is 32 bytes
   * @param _data Message data
   */
  modifier checkMessageLength(bytes memory _data) {
    if (!_checkMessageLength(_data)) revert ScrollSpokeConnector_LengthIsNot32();
    _;
  }

  /**
   * @notice Renounces ownership
   * @dev Should not be able to renounce ownership
   */
  function renounceOwnership() public virtual override(ProposedOwnable, SpokeConnector) onlyOwner {}

  /**
   * @notice Sends a message to the mirror connector through the L2 Scroll Messenger
   * @param _data Message data
   * @dev The message length must be 32 bytes
   */
  function _sendMessage(bytes memory _data, bytes memory) internal override checkMessageLength(_data) {
    bytes memory _calldata = abi.encodeWithSelector(Connector.processMessage.selector, _data);
    L2_SCROLL_MESSENGER.sendMessage(mirrorConnector, ZERO_MSG_VALUE, _calldata, gasCap);
  }

  /**
   * @notice Receives a message from the L1 Scroll Hub Connector through the L2 Scroll Messenger
   * @param _data Message data
   * @dev The sender must be the L1 Scroll Messenger
   * @dev The message length must be 32 bytes
   * @dev The origin sender of the cross domain message must be the mirror connector
   */
  function _processMessage(bytes memory _data) internal override onlyAMB checkMessageLength(_data) {
    if (!_verifySender(mirrorConnector)) revert ScrollSpokeConnector_OriginSenderIsNotMirror();
    receiveAggregateRoot(bytes32(_data));
  }

  /**
   * @notice Verifies that the origin sender of the cross domain message is the mirror connector
   * @param _mirrorConnector Mirror connector address
   * @return _isValid True if the origin sender is the mirror connector, otherwise false
   */
  function _verifySender(address _mirrorConnector) internal view override returns (bool _isValid) {
    _isValid = L2_SCROLL_MESSENGER.xDomainMessageSender() == _mirrorConnector;
  }
}
