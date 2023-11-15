// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.17;

import {BaseScroll} from "./BaseScroll.sol";
import {Connector} from "../Connector.sol";
import {SpokeConnector} from "../SpokeConnector.sol";
import {ProposedOwnable} from "../../../../contracts/shared/ProposedOwnable.sol";
import {WatcherClient} from "../../WatcherClient.sol";

contract ScrollSpokeConnector is SpokeConnector, BaseScroll {
  error ScrollSpokeConnector_LengthIsNot32();
  error ScrollSpokeConnector_OriginSenderIsNotMirror();

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
    BaseScroll(_amb, _gasCap)
  {}

  modifier checkMessageLength(bytes memory _data) {
    if (!_checkMessageLength(_data)) revert ScrollSpokeConnector_LengthIsNot32();
    _;
  }

  function renounceOwnership() public virtual override(ProposedOwnable, SpokeConnector) onlyOwner {}

  function _sendMessage(bytes memory _data, bytes memory) internal override checkMessageLength(_data) {
    _sendMessageToAMB(_data, mirrorConnector);
  }

  function _processMessage(bytes memory _data) internal override onlyAMB checkMessageLength(_data) {
    if (!_verifySender(mirrorConnector)) revert ScrollSpokeConnector_OriginSenderIsNotMirror();
    receiveAggregateRoot(bytes32(_data));
  }

  function _verifySender(address _mirrorConnector) internal view override returns (bool _isValid) {
    _isValid = _verifyOriginSender(_mirrorConnector);
  }
}
