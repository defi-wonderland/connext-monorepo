// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {BaseScroll} from "../../../../../../contracts/messaging/connectors/scroll/BaseScroll.sol";
import {Connector} from "../../../../../../contracts/messaging/connectors/Connector.sol";
import {ConnectorHelper} from "../../../../../utils/ConnectorHelper.sol";
import {ScrollSpokeConnector} from "../../../../../../contracts/messaging/connectors/scroll/scrollSpokeConnector.sol";
import {MerkleTreeManager} from "../../../../../../contracts/messaging/MerkleTreeManager.sol";
import {ProposedOwnable} from "../../../../../../contracts/shared/ProposedOwnable.sol";
import {IRootManager} from "../../../../../../contracts/messaging/interfaces/IRootManager.sol";
import {Common} from "./Common.sol";

contract IntegrationScrollSpokeConnector is Common {
  event AggregateRootReceived(bytes32 root);

  event SentMessage(
    address indexed sender,
    address indexed target,
    uint256 value,
    uint256 messageNonce,
    uint256 gasLimit,
    bytes message
  );

  function test_sendMessage() public {
    // Get the root that will be sent from the merkle tree manager
    bytes32 _root = merkleTreeManager.root();
    bytes memory _data = abi.encodePacked(_root);
    bytes memory _functionCall = abi.encodeWithSelector(Connector.processMessage.selector, _data);

    // Expect the `SentMessage` event to be emitted by the scroll messenger AMB
    vm.expectEmit(true, true, true, true, address(L2_SCROLL_MESSENGER));
    uint256 _nonce = 11766;
    emit SentMessage(
      address(scrollSpokeConnector),
      mirrorConnector,
      scrollSpokeConnector.ZERO_MSG_VALUE(),
      _nonce,
      _gasCap,
      _functionCall
    );

    vm.prank(user);
    bytes memory _extraData = "";
    scrollSpokeConnector.send(_extraData);
  }

  function test_processMessage() public {
    // Get a root and parse it
    bytes32 _root = merkleTreeManager.root();
    bytes memory _data = abi.encodePacked(_root);

    // Expect the `AggregateRootReceived` event to be emitted by scroll spoke connector
    vm.expectEmit(true, true, true, true, address(scrollSpokeConnector));
    emit AggregateRootReceived(_root);

    // Relay the message on the AMB and expect the `processMessage` function to be called on scroll spoke connector
    vm.prank(SCROLL_RELAYER);
    L2_SCROLL_MESSENGER.relayMessage(
      mirrorConnector,
      address(scrollSpokeConnector),
      0,
      0,
      abi.encodeWithSelector(Connector.processMessage.selector, _data)
    );
  }
}
