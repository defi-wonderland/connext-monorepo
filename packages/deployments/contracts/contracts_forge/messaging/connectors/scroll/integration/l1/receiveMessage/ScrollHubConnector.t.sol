// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {BaseScroll} from "../../../../../../../contracts/messaging/connectors/scroll/BaseScroll.sol";
import {Connector} from "../../../../../../../contracts/messaging/connectors/Connector.sol";
import {ConnectorHelper} from "../../../../../../utils/ConnectorHelper.sol";
import {ScrollHubConnector} from "../../../../../../../contracts/messaging/connectors/scroll/scrollHubConnector.sol";
import {MerkleTreeManager} from "../../../../../../../contracts/messaging/MerkleTreeManager.sol";
import {ProposedOwnable} from "../../../../../../../contracts/shared/ProposedOwnable.sol";
import {IL1ScrollMessenger} from "../../../../../../../contracts/messaging/interfaces/ambs/scroll/IL1ScrollMessenger.sol";
import {IRootManager} from "../../../../../../../contracts/messaging/interfaces/IRootManager.sol";
import {Common} from "./Common.sol";
import {L1ScrollMessengerForTest} from "./L1ScrollMessengerForTest.sol";

contract IntegrationScrollHubConnector_ReceiveMessage is Common {
  event RootReceived(uint32 domain, bytes32 receivedRoot, uint256 queueIndex);

  function test_processMessage() public {
    // Get a root and parse it
    bytes32 _root = merkleTreeManager.root();
    bytes memory _data = abi.encodePacked(_root);

    // Expect the `RootReceived` event to be emitted by scroll hub connector
    vm.expectEmit(true, true, true, true, address(rootManager));
    uint128 _lastIndex = 1;
    emit RootReceived(MIRROR_DOMAIN, _root, _lastIndex);

    vm.prank(relayer);
    l1ScrollMessenger.relayMessage(
      mirrorConnector,
      address(scrollHubConnector),
      0,
      0,
      abi.encodeWithSelector(Connector.processMessage.selector, _data)
    );
  }
}
