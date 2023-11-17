// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.17;

import {BaseScroll} from "./BaseScroll.sol";
import {Connector} from "../Connector.sol";
import {SpokeConnector} from "../SpokeConnector.sol";
import {ProposedOwnable} from "../../../../contracts/shared/ProposedOwnable.sol";
import {WatcherClient} from "../../WatcherClient.sol";
import {IL2ScrollMessenger} from "../../interfaces/ambs/scroll/IL2ScrollMessenger.sol";

contract ScrollSpokeConnector is SpokeConnector, BaseScroll {
  error ScrollSpokeConnector_LengthIsNot32();
  error ScrollSpokeConnector_OriginSenderIsNotMirror();

  IL2ScrollMessenger public immutable L2_SCROLL_MESSENGER;

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

  modifier checkMessageLength(bytes memory _data) {
    if (!_checkMessageLength(_data)) revert ScrollSpokeConnector_LengthIsNot32();
    _;
  }

  function renounceOwnership() public virtual override(ProposedOwnable, SpokeConnector) onlyOwner {}

  function _sendMessage(bytes memory _data, bytes memory) internal override checkMessageLength(_data) {
    bytes memory _calldata = abi.encodeWithSelector(Connector.processMessage.selector, _data);
    L2_SCROLL_MESSENGER.sendMessage(mirrorConnector, ZERO_MSG_VALUE, _calldata, gasCap);
  }

  function _processMessage(bytes memory _data) internal override onlyAMB checkMessageLength(_data) {
    if (!_verifySender(mirrorConnector)) revert ScrollSpokeConnector_OriginSenderIsNotMirror();
    receiveAggregateRoot(bytes32(_data));
  }

  function _verifySender(address _mirrorConnector) internal view override returns (bool _isValid) {
    _isValid = L2_SCROLL_MESSENGER.xDomainMessageSender() == _mirrorConnector;
  }
}
