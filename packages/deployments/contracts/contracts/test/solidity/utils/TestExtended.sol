// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import 'forge-std/Test.sol';

contract TestExtended is Test {

  function _expectEmit(address _contract) internal {
    vm.expectEmit(true, true, true, true, _contract);
  }
}