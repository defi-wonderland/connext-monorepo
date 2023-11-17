// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.17;

import {BaseScroll} from "./BaseScroll.sol";
import {Connector} from "../Connector.sol";
import {HubConnector} from "../HubConnector.sol";
import {IL1ScrollMessenger} from "../../interfaces/ambs/scroll/IL1ScrollMessenger.sol";
import {IRootManager} from "../../interfaces/IRootManager.sol";

contract ScrollHubConnector is HubConnector, BaseScroll {
  error ScrollHubConnector_LengthIsNot32();
  error ScrollHubConnector_OriginSenderIsNotMirror();

  IL1ScrollMessenger public immutable L1_SCROLL_MESSENGER;

  constructor(
    uint32 _domain,
    uint32 _mirrorDomain,
    address _amb,
    address _rootManager,
    address _mirrorConnector,
    uint256 _gasCap
  ) HubConnector(_domain, _mirrorDomain, _amb, _rootManager, _mirrorConnector) BaseScroll(_gasCap) {
    L1_SCROLL_MESSENGER = IL1ScrollMessenger(_amb);
  }

  modifier checkMessageLength(bytes memory _data) {
    if (!_checkMessageLength(_data)) revert ScrollHubConnector_LengthIsNot32();
    _;
  }

  function _sendMessage(bytes memory _data, bytes memory _encodedData) internal override checkMessageLength(_data) {
    address _refundAddress;
    if (_encodedData.length > 0) _refundAddress = abi.decode(_encodedData, (address));
    bytes memory _calldata = abi.encodeWithSelector(Connector.processMessage.selector, _data);
    L1_SCROLL_MESSENGER.sendMessage{value: msg.value}(
      mirrorConnector,
      ZERO_MSG_VALUE,
      _calldata,
      gasCap,
      _refundAddress
    );
  }

  function _processMessage(bytes memory _data) internal override onlyAMB checkMessageLength(_data) {
    if (!_verifySender(mirrorConnector)) revert ScrollHubConnector_OriginSenderIsNotMirror();
    IRootManager(ROOT_MANAGER).aggregate(MIRROR_DOMAIN, bytes32(_data));
  }

  function _verifySender(address _mirrorConnector) internal view override returns (bool _isValid) {
    _isValid = L1_SCROLL_MESSENGER.xDomainMessageSender() == _mirrorConnector;
  }
}
