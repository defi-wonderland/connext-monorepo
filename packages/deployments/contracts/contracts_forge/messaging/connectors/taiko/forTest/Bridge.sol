// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {AddressResolver} from "../common/AddressResolver.sol";
import {BridgeErrors} from "./BridgeErrors.sol";
import {EssentialContract} from "../common/EssentialContract.sol";
import {IBridge} from "./IBridge.sol";
import {LibBridgeData} from "./libs/LibBridgeData.sol";
import {LibBridgeProcess} from "./libs/LibBridgeProcess.sol";
import {LibBridgeSend} from "./libs/LibBridgeSend.sol";

/// @title Bridge
/// @notice See the documentation for {IBridge}.
/// @dev The code hash for the same address on L1 and L2 may be different.
contract BridgeForTest is EssentialContract, IBridge, BridgeErrors {
  using LibBridgeData for Message;

  LibBridgeData.State private _state; // 50 slots reserved

  event DestChainEnabled(uint256 indexed chainId, bool enabled);

  receive() external payable {}

  /// @notice Initializes the contract.
  /// @param _addressManager The address of the {AddressManager} contract.
  function init(address _addressManager) external initializer {
    EssentialContract._init(_addressManager);
  }

  /// @notice Sends a message from the current chain to the destination chain
  /// specified in the message.
  /// @inheritdoc IBridge
  function sendMessage(Message calldata message) external payable nonReentrant returns (bytes32 msgHash) {
    return LibBridgeSend.sendMessage({state: _state, resolver: AddressResolver(this), message: message});
  }

  /// @notice Processes a message received from another chain.
  /// @inheritdoc IBridge
  function processMessage(Message calldata message, bytes calldata proof) external nonReentrant {
    return
      LibBridgeProcess.processMessage({
        state: _state,
        resolver: AddressResolver(this),
        message: message,
        proof: proof,
        checkProof: shouldCheckProof()
      });
  }

  /// @notice Checks if the message with the given hash has been sent on its
  /// source chain.
  /// @inheritdoc IBridge
  function isMessageSent(bytes32 msgHash) public view virtual returns (bool) {
    return LibBridgeSend.isMessageSent(AddressResolver(this), msgHash);
  }

  /// @notice Gets the current context.
  /// @inheritdoc IBridge
  function context() public view returns (Context memory) {
    return _state.ctx;
  }

  /// @notice Checks if the destination chain with the given ID is enabled.
  /// @param _chainId The ID of the chain.
  /// @return enabled Returns true if the destination chain is enabled, false
  /// otherwise.
  function isDestChainEnabled(uint256 _chainId) public view returns (bool enabled) {
    (enabled, ) = LibBridgeSend.isDestChainEnabled(AddressResolver(this), _chainId);
  }

  /// @notice Computes the hash of a given message.
  /// @inheritdoc IBridge
  function hashMessage(Message calldata message) public pure returns (bytes32) {
    return LibBridgeData.hashMessage(message);
  }

  /// @notice Tells if we need to check real proof or it is a test.
  /// @return Returns true if this contract, or can be false if mock/test.
  function shouldCheckProof() internal pure virtual returns (bool) {
    return true;
  }
}
