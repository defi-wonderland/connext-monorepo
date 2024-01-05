// SPPX-LicenseIdentifier: MIT
pragma solidity =0.8.17;

import {Common} from "./Common.sol";
import {Connector} from "../../../../../../contracts/messaging/connectors/Connector.sol";
import {IBridge} from "../../../../../../contracts/messaging/interfaces/ambs/taiko/IBridge.sol";

contract Integration_Connector_TaikoSpokeConnector is Common {
  /**
   * @notice Emitted on Taiko's Bridge contract when a message is sent through it
   * @param msgHash The message hash
   * @param message The message
   */
  event MessageSent(bytes32 indexed msgHash, IBridge.Message message);

  /**
   * @notice Tests that the tx for sending the message through the taiko signal service succeeds
   */
  function test_sendMessage() public {
    // Get the merkle root (the signal that was sent)
    bytes32 _root = merkleTreeManager.root();
    bytes memory _calldata = abi.encodeWithSelector(Connector.processMessage.selector, abi.encode(_root));

    // Next id grabbed from the Taiko's Bridge state on the current block number
    uint256 _id = 159241;
    IBridge.Message memory _message = IBridge.Message({
      id: _id,
      from: address(taikoSpokeConnector),
      srcChainId: block.chainid,
      destChainId: taikoSpokeConnector.HUB_CHAIN_ID(),
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

    // Send message
    vm.prank(user);
    bytes memory _encodedData = "";
    taikoSpokeConnector.send(_encodedData);
  }
}
