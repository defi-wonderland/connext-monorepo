// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.17;

import {IRootManager} from "../../../../contracts/messaging/interfaces/IRootManager.sol";
import {ScrollHubConnector} from "../../../../contracts/messaging/connectors/scroll/scrollHubConnector.sol";
import {IL1ScrollMessenger} from "../../../../contracts/messaging/interfaces/ambs/scroll/IL1ScrollMessenger.sol";
import {ConnectorHelper} from "../../../utils/ConnectorHelper.sol";

contract Base is ConnectorHelper {
  ScrollHubConnector public scrollHubConnector;

  function setUp() public {
    _l2Connector = payable(makeAddr("ScrollSpokeConnector"));
    scrollHubConnector = new ScrollHubConnector(_l1Domain, _l2Domain, _amb, _rootManager, _l2Connector, _gasCap);
  }
}

contract ScrollHubConnector_Constructor is Base {
  function test_checkConstructorArgs() public {
    assertEq(scrollHubConnector.DOMAIN(), _l1Domain);
    assertEq(scrollHubConnector.MIRROR_DOMAIN(), _l2Domain);
    assertEq(scrollHubConnector.AMB(), _amb);
    assertEq(scrollHubConnector.mirrorConnector(), _l2Connector);
    //TODO: WTF
    // assertEq(scrollHubConnector.gasCap(), _gasCap);
  }
}
