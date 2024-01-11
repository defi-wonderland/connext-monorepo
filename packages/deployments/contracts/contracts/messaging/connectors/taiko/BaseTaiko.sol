// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {Connector} from "../Connector.sol";
import {GasCap} from "../GasCap.sol";
import {IBridge} from "../../interfaces/ambs/taiko/IBridge.sol";

/**
 * @title BaseTaiko
 * @notice Base contract for Taiko Hub and Spoke Connectors
 */
abstract contract BaseTaiko is GasCap {
  /**
   * @notice Taiko Signal Service address
   */
  IBridge public immutable BRIDGE;

  /**
   * @param _taikoBridge Taiko Signal Service address
   */
  constructor(address _taikoBridge, uint256 _gasCap) GasCap(_gasCap) {
    BRIDGE = IBridge(_taikoBridge);
  }

  function _sendMessage(bytes memory _data, uint256 _destinationChainId, address _mirrorConnector) internal {
    bytes memory _calldata = abi.encodeWithSelector(Connector.processMessage.selector, _data);
    IBridge.Message memory _message = IBridge.Message({
      id: 0,
      from: address(this),
      srcChainId: block.chainid,
      destChainId: _destinationChainId,
      user: msg.sender,
      to: _mirrorConnector,
      refundTo: _mirrorConnector,
      value: 0,
      fee: 0,
      gasLimit: gasCap,
      data: _calldata,
      memo: ""
    });
    BRIDGE.sendMessage(_message);
  }

  function _verifySrcChain(uint256 _msgSrcChain, uint256 _mirrorChainId) internal pure returns (bool _isValid) {
    _isValid = _msgSrcChain == _mirrorChainId;
  }
}
