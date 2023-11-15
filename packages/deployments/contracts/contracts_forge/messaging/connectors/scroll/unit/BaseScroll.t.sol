// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.17;

import {BaseScroll} from "../../../../../contracts/messaging/connectors/scroll/BaseScroll.sol";
import {Connector} from "../../../../../contracts/messaging/connectors/Connector.sol";
import {ConnectorHelper} from "../../../../utils/ConnectorHelper.sol";
import {IScrollMessenger} from "../../../../../contracts/messaging/interfaces/ambs/scroll/IScrollMessenger.sol";

contract BaseScrollForTest is BaseScroll {
  constructor(address _amb, uint256 _gasCap) BaseScroll(_amb, _gasCap) {}

  function forTest_gasCap() public view returns (uint256 _gasCap) {
    _gasCap = gasCap;
  }

  function forTest_checkMessageLength(bytes memory _data) external pure returns (bool _isValid) {
    _isValid = _checkMessageLength(_data);
  }

  function forTest_sendMessageToAMB(bytes memory _data, address _mirrorConnector) external {
    _sendMessageToAMB(_data, _mirrorConnector);
  }

  function forTest_verifyOriginSender(address _expected) external view returns (bool _isValid) {
    _isValid = _verifyOriginSender(_expected);
  }
}

contract Base is ConnectorHelper {
  address public user = makeAddr("user");
  BaseScrollForTest public baseScroll;

  function setUp() public {
    baseScroll = new BaseScrollForTest(_amb, _gasCap);
  }
}

contract BaseScroll_Constructor is Base {
  function test_deploymentArgs() public {
    assertEq(address(baseScroll.SCROLL_MESSENGER()), _amb);
    assertEq(baseScroll.forTest_gasCap(), _gasCap);
  }
}

contract BaseScroll_CheckMessageLength is Base {
  function test_returnFalseOnInvalidLength(bytes memory _data) public {
    vm.assume(_data.length != 32);
    assertEq(baseScroll.forTest_checkMessageLength(_data), false);
  }

  function test_checkMessageLength() public {
    bytes memory _data = new bytes(32);
    assertEq(baseScroll.forTest_checkMessageLength(_data), true);
  }
}

contract BaseScroll_SendMessageToAMB is Base {
  function test_callAMB(bytes memory _data, address _mirrorConnector) public {
    bytes memory _functionCall = abi.encodeWithSelector(Connector.processMessage.selector, _data);
    _mockAndExpect(
      _amb,
      abi.encodeWithSelector(
        IScrollMessenger.sendMessage.selector,
        _mirrorConnector,
        baseScroll.ZERO_MSG_VALUE(),
        _functionCall,
        _gasCap
      ),
      ""
    );

    vm.prank(user);
    baseScroll.forTest_sendMessageToAMB(_data, _mirrorConnector);
  }
}

contract BaseScroll_VerifyOriginSender is Base {
  function test_returnFalseIfSenderIsNotMirror(address _originSender, address _mirrorConnector) public {
    vm.assume(_originSender != _mirrorConnector);
    vm.mockCall(
      _amb,
      abi.encodeWithSelector(IScrollMessenger.xDomainMessageSender.selector),
      abi.encode(_mirrorConnector)
    );
    assertEq(baseScroll.forTest_verifyOriginSender(_originSender), false);
  }

  function test_returnTrueIfSenderIsMirror(address _mirrorConnector) public {
    vm.mockCall(
      _amb,
      abi.encodeWithSelector(IScrollMessenger.xDomainMessageSender.selector),
      abi.encode(_mirrorConnector)
    );
    assertEq(baseScroll.forTest_verifyOriginSender(_mirrorConnector), true);
  }
}
