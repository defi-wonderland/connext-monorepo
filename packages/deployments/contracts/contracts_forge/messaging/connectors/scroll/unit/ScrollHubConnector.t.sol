// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.17;

import {BaseScroll} from "../../../../../contracts/messaging/connectors/scroll/BaseScroll.sol";
import {Connector} from "../../../../../contracts/messaging/connectors/Connector.sol";
import {ConnectorHelper} from "../../../../utils/ConnectorHelper.sol";
import {ScrollHubConnector} from "../../../../../contracts/messaging/connectors/scroll/scrollHubConnector.sol";
import {IScrollMessenger} from "../../../../../contracts/messaging/interfaces/ambs/scroll/IScrollMessenger.sol";
import {IRootManager} from "../../../../../contracts/messaging/interfaces/IRootManager.sol";

contract ScrollHubConnectorForTest is ScrollHubConnector {
  constructor(
    uint32 _domain,
    uint32 _mirrorDomain,
    address _amb,
    address _rootManager,
    address _mirrorConnector,
    uint256 _gasCap
  ) ScrollHubConnector(_domain, _mirrorDomain, _amb, _rootManager, _mirrorConnector, _gasCap) {}

  function forTest_gasCap() public view returns (uint256 _gasCap) {
    _gasCap = gasCap;
  }

  function forTest_sendMessage(bytes memory _data, bytes memory _extraData) external {
    _sendMessage(_data, _extraData);
  }

  function forTest_processMessage(bytes memory _data) external {
    _processMessage(_data);
  }

  function forTest_verifySender(address _expected) external view returns (bool _isValid) {
    _isValid = _verifySender(_expected);
  }
}

contract Base is ConnectorHelper {
  address public user = makeAddr("user");
  address public owner = makeAddr("owner");
  address public stranger = makeAddr("stranger");
  bytes32 public rootSnapshot = keccak256(abi.encodePacked("rootSnapshot"));
  bytes32 public aggregateRoot = keccak256(abi.encodePacked("aggregateRoot"));
  ScrollHubConnectorForTest public scrollHubConnector;
  uint256 public constant DELAY_BLOCKS = 0;

  function setUp() public {
    vm.prank(owner);
    scrollHubConnector = new ScrollHubConnectorForTest(_l1Domain, _l2Domain, _amb, _rootManager, _l2Connector, _gasCap);
  }
}

contract ScrollHubConnector_Constructor is Base {
  function test_checkConstructorArgs() public {
    assertEq(scrollHubConnector.DOMAIN(), _l1Domain);
    assertEq(scrollHubConnector.MIRROR_DOMAIN(), _l2Domain);
    assertEq(scrollHubConnector.AMB(), _amb);
    assertEq(scrollHubConnector.ROOT_MANAGER(), _rootManager);
    assertEq(scrollHubConnector.mirrorConnector(), _l2Connector);
    assertEq(scrollHubConnector.forTest_gasCap(), _gasCap);
  }
}

contract ScrollHubConnector_SendMessage is Base {
  function test_revertIfDataIsNot32Length(bytes memory _data) public {
    vm.assume(_data.length != 32);
    bytes memory _encodedData = "";

    vm.prank(user);
    vm.expectRevert(ScrollHubConnector.ScrollHubConnector_LengthIsNot32.selector);
    scrollHubConnector.forTest_sendMessage(_data, _encodedData);
  }

  function test_callAMBSendMessage() public {
    bytes memory _data = new bytes(32);
    bytes memory _encodedData = "";
    bytes memory _functionCall = abi.encodeWithSelector(Connector.processMessage.selector, _data);

    _mockAndExpect(
      _amb,
      abi.encodeWithSelector(
        IScrollMessenger.sendMessage.selector,
        _l2Connector,
        scrollHubConnector.ZERO_MSG_VALUE(),
        _functionCall,
        _gasCap
      ),
      ""
    );

    vm.prank(user);
    scrollHubConnector.forTest_sendMessage(_data, _encodedData);
  }
}

contract ScrollHubConnector_ProcessMessage is Base {
  event AggregateRootReceived(bytes32 _root);

  function test_revertIfSenderIsNotAMB(address _sender) public {
    vm.assume(_sender != _amb);
    bytes memory _data = _convertbytes32ToBytes(rootSnapshot);

    vm.prank(_sender);
    vm.expectRevert();
    scrollHubConnector.processMessage(_data);
  }

  function test_revertIfDataIsNot32Length(bytes memory _data) public {
    vm.assume(_data.length != 32);
    vm.prank(_amb);
    vm.expectRevert(ScrollHubConnector.ScrollHubConnector_LengthIsNot32.selector);
    scrollHubConnector.processMessage(_data);
  }

  function test_revertIfOriginSenderNotMirror() public {
    bytes memory _data = _convertbytes32ToBytes(rootSnapshot);
    // Mock the x domain message sender to be a stranger and not the mirror connector
    vm.mockCall(_amb, abi.encodeWithSelector(IScrollMessenger.xDomainMessageSender.selector), abi.encode(stranger));

    vm.prank(_amb);
    vm.expectRevert(ScrollHubConnector.ScrollHubConnector_OriginSenderIsNotMirror.selector);
    scrollHubConnector.processMessage(_data);
  }

  function test_callAggregate() public {
    // Mock the root to a real one
    bytes memory _data = _convertbytes32ToBytes(aggregateRoot);

    // Mock the x domain message sender as if it is the mirror connector
    address _mirrorConnector = scrollHubConnector.mirrorConnector();
    vm.mockCall(
      _amb,
      abi.encodeWithSelector(IScrollMessenger.xDomainMessageSender.selector),
      abi.encode(_mirrorConnector)
    );

    uint32 _mirrorDomain = _l2Domain;
    _mockAndExpect(
      _rootManager,
      abi.encodeWithSelector(IRootManager.aggregate.selector, _mirrorDomain, bytes32(_data)),
      ""
    );

    vm.prank(_amb);
    scrollHubConnector.processMessage(_data);
  }
}

contract ScrollHubConnector_VerifySender is Base {
  function test_returnFalseIfOriginSenderNotMirror(address _originSender, address _mirrorConnector) public {
    vm.assume(_originSender != _mirrorConnector);
    vm.mockCall(
      _amb,
      abi.encodeWithSelector(IScrollMessenger.xDomainMessageSender.selector),
      abi.encode(_originSender)
    );
    assertEq(scrollHubConnector.forTest_verifySender(_mirrorConnector), false);
  }

  function test_returnTrueIfOriginSenderIsMirror(address _mirrorConnector) public {
    vm.mockCall(
      _amb,
      abi.encodeWithSelector(IScrollMessenger.xDomainMessageSender.selector),
      abi.encode(_mirrorConnector)
    );
    vm.prank(_mirrorConnector);
    assertEq(scrollHubConnector.forTest_verifySender(_mirrorConnector), true);
  }
}
