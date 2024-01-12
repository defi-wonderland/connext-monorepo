// SPDX-License-Identifier: MIT

pragma solidity =0.8.17;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/// @title Proxied
/// @dev This abstract contract extends Initializable from OpenZeppelin's
/// upgradeable contracts library. It is intended to be used for proxy pattern
/// implementations where constructors are non-traditional.
abstract contract Proxied is Initializable {
  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }
}
