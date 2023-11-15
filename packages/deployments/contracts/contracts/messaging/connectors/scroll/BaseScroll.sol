// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.17;

import {GasCap} from "../GasCap.sol";
import {Connector} from "../Connector.sol";
import {SpokeConnector} from "../SpokeConnector.sol";
import {IScrollMessenger} from "../../interfaces/ambs/scroll/IScrollMessenger.sol";

abstract contract BaseScroll is GasCap {
  uint256 public constant ZERO_MSG_VALUE = 0;
  uint256 public constant MESSAGE_LENGTH = 32;
  IScrollMessenger public immutable SCROLL_MESSENGER;

  constructor(address _scrollMessenger, uint256 _gasCap) GasCap(_gasCap) {
    SCROLL_MESSENGER = IScrollMessenger(_scrollMessenger);
  }

  function _checkMessageLength(bytes memory _data) internal pure returns (bool _validLength) {
    _validLength = _data.length == MESSAGE_LENGTH;
  }

  function _sendMessageToAMB(bytes memory _data, address _mirrorConnector) internal {
    bytes memory _calldata = abi.encodeWithSelector(Connector.processMessage.selector, _data);
    SCROLL_MESSENGER.sendMessage(_mirrorConnector, ZERO_MSG_VALUE, _calldata, gasCap);
  }

  function _verifyOriginSender(address _mirrorConnector) internal view returns (bool) {
    return SCROLL_MESSENGER.xDomainMessageSender() == _mirrorConnector;
  }
}
