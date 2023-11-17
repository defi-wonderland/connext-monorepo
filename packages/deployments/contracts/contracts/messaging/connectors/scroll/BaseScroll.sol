// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.17;

import {GasCap} from "../GasCap.sol";
import {Connector} from "../Connector.sol";
import {SpokeConnector} from "../SpokeConnector.sol";

abstract contract BaseScroll is GasCap {
  uint256 public constant ZERO_MSG_VALUE = 0;
  uint256 public constant MESSAGE_LENGTH = 32;

  constructor(uint256 _gasCap) GasCap(_gasCap) {}

  function _checkMessageLength(bytes memory _data) internal pure returns (bool _validLength) {
    _validLength = _data.length == MESSAGE_LENGTH;
  }
}
