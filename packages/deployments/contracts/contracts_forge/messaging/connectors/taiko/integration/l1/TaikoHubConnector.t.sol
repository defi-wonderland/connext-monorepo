// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Common} from "./Common.sol";
import {Connector} from "../../../../../../contracts/messaging/connectors/Connector.sol";
import {IBridge} from "../../../../../../contracts/messaging/interfaces/ambs/taiko/IBridge.sol";

contract Integration_Connector_TaikoHubConnector is Common {
  /**
   * @notice Emitted on Taiko's Bridge contract when a message is sent through it
   * @param msgHash The message hash
   * @param message The message
   */
  event MessageSent(bytes32 indexed msgHash, IBridge.Message message);

  /**
   * @notice Tests that the tx for sending the message through the taik signal service the message
   */
  function test_sendMessage() public {
    bytes memory _data = abi.encode(bytes32("aggregateRoot"));
    bytes memory _calldata = abi.encodeWithSelector(Connector.processMessage.selector, _data);
    // Next id grabbed from the Taiko's Bridge state on the current block number

    uint256 _id = 728233;
    IBridge.Message memory _message = IBridge.Message({
      id: _id,
      from: address(taikoHubConnector),
      srcChainId: block.chainid,
      destChainId: taikoHubConnector.SPOKE_CHAIN_ID(),
      user: mirrorConnector,
      to: mirrorConnector,
      refundTo: mirrorConnector,
      value: 0,
      fee: 0,
      gasLimit: _gasCap,
      data: _calldata,
      memo: ""
    });
    vm.expectEmit(true, true, true, true, address(BRIDGE));
    emit MessageSent(keccak256(abi.encode(_message)), _message);

    // Send message from the root manager
    vm.prank(address(rootManager));
    bytes memory _encodedData = "";
    taikoHubConnector.sendMessage(_data, _encodedData);
  }
}
