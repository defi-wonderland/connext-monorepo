// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.17;

import {BaseScroll} from "./BaseScroll.sol";
import {Connector} from "../Connector.sol";
import {HubConnector} from "../HubConnector.sol";
import {IRootManager} from "../../interfaces/IRootManager.sol";

contract ScrollHubConnector is HubConnector, BaseScroll {
  error ScrollHubConnector_LengthIsNot32();
  error ScrollHubConnector_OriginSenderIsNotMirror();

  constructor(
    uint32 _domain,
    uint32 _mirrorDomain,
    address _amb,
    address _rootManager,
    address _mirrorConnector,
    uint256 _gasCap
  ) HubConnector(_domain, _mirrorDomain, _amb, _rootManager, _mirrorConnector) BaseScroll(_amb, _gasCap) {}

  modifier checkMessageLength(bytes memory _data) {
    if (!_checkMessageLength(_data)) revert ScrollHubConnector_LengthIsNot32();
    _;
  }

  function _sendMessage(bytes memory _data, bytes memory) internal override checkMessageLength(_data) {
    _sendMessageToAMB(_data, mirrorConnector);
  }

  function _processMessage(bytes memory _data) internal override onlyAMB checkMessageLength(_data) {
    if (!_verifySender(mirrorConnector)) revert ScrollHubConnector_OriginSenderIsNotMirror();
    IRootManager(ROOT_MANAGER).aggregate(MIRROR_DOMAIN, bytes32(_data));
  }

  function _verifySender(address _mirrorConnector) internal view override returns (bool _isValid) {
    _isValid = _verifyOriginSender(_mirrorConnector);
  }
}
