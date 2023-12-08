// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Common} from "./Common.sol";

contract Integration_Connector_TaikoHubConnector_ReceiveMessage is Common {
  /**
   * @notice Tests that the message is received and processed correctly
   */
  function test_receiveMessage() public {
    vm.prank(offChainAgent);
    bytes memory _data = abi.encode(SIGNAL, PROOF);
    taikoHubConnector.processMessage(_data);
  }
}
