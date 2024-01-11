// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Common} from "./Common.sol";
import {Connector} from "../../../../../../../contracts/messaging/connectors/Connector.sol";
import {IBridge} from "../../../../../../../contracts/messaging/interfaces/ambs/taiko/IBridge.sol";

contract Integration_Connector_TaikoSpokeConnector_Send is Common {
  /**
   * @notice Emitted on Taiko's Bridge contract when a message is sent through it
   * @param msgHash The message hash
   * @param message The message
   */
  event MessageSent(bytes32 indexed msgHash, IBridge.Message message);

  /**
   * @notice Tests the message is sent correctly through the Taiko's Bridge contract when calling Taiko Spoke Connector `send`.
   * @dev To validate the message is sent correctly, we check the Bridge contract emits the `MessageSent` event with the correct arguments.
   */
  function test_sendMessage() public {
    bytes32 _root = merkleTreeManager.root();
    bytes memory _calldata = abi.encodeWithSelector(Connector.processMessage.selector, abi.encode(_root));

    // Next id grabbed from the Taiko's Bridge state on the current block number
    uint256 _id = 219838;
    // Declare the message that should be emitted
    IBridge.Message memory _message = IBridge.Message({
      id: _id,
      from: address(taikoSpokeConnector),
      srcChainId: TAIKO_CHAIN_ID,
      destChainId: SEPOLIA_CHAIN_ID,
      user: user,
      to: mirrorConnector,
      refundTo: mirrorConnector,
      value: 0,
      fee: 0,
      gasLimit: _gasCap,
      data: _calldata,
      memo: ""
    });

    // Expect the `MessageSent` event to be emitted correctly with the message on taiko bridge
    bytes32 _msgHash = keccak256(abi.encode(_message));
    vm.expectEmit(true, true, true, true, address(BRIDGE));
    emit MessageSent(_msgHash, _message);

    // Send message
    vm.prank(user);
    bytes memory _encodedData = "";
    taikoSpokeConnector.send(_encodedData);
  }

  /**
   * @notice Tests it reverts when the same root is sent twice
   */
  function test_revertIfSameRootIsSentTwice() public {
    vm.startPrank(user);
    bytes memory _encodedData = "";
    taikoSpokeConnector.send(_encodedData);

    vm.expectRevert("root already sent");
    taikoSpokeConnector.send(_encodedData);
  }
}
