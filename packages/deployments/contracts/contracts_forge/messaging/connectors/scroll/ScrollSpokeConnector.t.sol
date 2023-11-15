// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.17;

import {BaseScroll} from "../../../../contracts/messaging/connectors/scroll/BaseScroll.sol";
import {Connector} from "../../../../contracts/messaging/connectors/Connector.sol";
import {ConnectorHelper} from "../../../utils/ConnectorHelper.sol";
import {ScrollSpokeConnector} from "../../../../contracts/messaging/connectors/scroll/scrollSpokeConnector.sol";
import {MerkleTreeManager} from "../../../../contracts/messaging/MerkleTreeManager.sol";
import {ProposedOwnable} from "../../../../contracts/shared/ProposedOwnable.sol";
import {IScrollMessenger} from "../../../../contracts/messaging/interfaces/ambs/scroll/IScrollMessenger.sol";
import {IL2ScrollMessenger} from "../../../../contracts/messaging/interfaces/ambs/scroll/IL2ScrollMessenger.sol";
import {IRootManager} from "../../../../contracts/messaging/interfaces/IRootManager.sol";

contract ScrollSpokeConnectorForTest is ScrollSpokeConnector {
  constructor(
    uint32 _domain,
    uint32 _mirrorDomain,
    address _amb,
    address _rootManager,
    address _mirrorConnector,
    uint256 _processGas,
    uint256 _reserveGas,
    uint256 _delayBlocks,
    address _merkle,
    address _watcherManager,
    uint256 _gasCap
  )
    ScrollSpokeConnector(
      _domain,
      _mirrorDomain,
      _amb,
      _rootManager,
      _mirrorConnector,
      _processGas,
      _reserveGas,
      _delayBlocks,
      _merkle,
      _watcherManager,
      _gasCap
    )
  {}

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
  address public watcherManager = makeAddr("WatcherManager");
  address public user = makeAddr("user");
  address public owner = makeAddr("owner");
  address public stranger = makeAddr("stranger");
  bytes32 public rootSnapshot = keccak256(abi.encodePacked("rootSnapshot"));
  bytes32 public aggregateRoot = keccak256(abi.encodePacked("aggregateRoot"));
  ScrollSpokeConnectorForTest public scrollSpokeConnector;
  uint256 public constant DELAY_BLOCKS = 0;

  function setUp() public {
    _merkle = address(new MerkleTreeManager());
    vm.prank(owner);
    scrollSpokeConnector = new ScrollSpokeConnectorForTest(
      _l1Domain,
      _l2Domain,
      _amb,
      _rootManager,
      _l2Connector,
      _processGas,
      _reserveGas,
      DELAY_BLOCKS,
      _merkle,
      watcherManager,
      _gasCap
    );
  }

  /**
   * @notice Combines mockCall and expectCall into one function
   *
   * @param _receiver   The receiver of the calls
   * @param _calldata   The encoded selector and the parameters of the call
   * @param _returned   The encoded data that the call should return
   */
  function _mockAndExpect(address _receiver, bytes memory _calldata, bytes memory _returned) internal {
    vm.mockCall(_receiver, _calldata, _returned);
    vm.expectCall(_receiver, _calldata);
  }

  function _convertbytes32ToBytes(bytes32 _data) internal pure returns (bytes memory _byteArray) {
    // Initialize a new bytes array with the same length as the bytes32
    _byteArray = new bytes(32);

    // Loop through each byte in the bytes32
    for (uint256 i = 0; i < 32; i++) {
      // Assign each byte of the bytes32 to the bytes array
      _byteArray[i] = _data[i];
    }
  }
}

contract ScrollSpokeConnector_Constructor is Base {
  function test_checkConstructorArgs() public {
    assertEq(scrollSpokeConnector.DOMAIN(), _l1Domain);
    assertEq(scrollSpokeConnector.MIRROR_DOMAIN(), _l2Domain);
    assertEq(scrollSpokeConnector.AMB(), _amb);
    assertEq(scrollSpokeConnector.ROOT_MANAGER(), _rootManager);
    assertEq(scrollSpokeConnector.mirrorConnector(), _l2Connector);
    assertEq(scrollSpokeConnector.PROCESS_GAS(), _processGas);
    assertEq(scrollSpokeConnector.RESERVE_GAS(), _reserveGas);
    assertEq(scrollSpokeConnector.delayBlocks(), DELAY_BLOCKS);
    assertEq(address(scrollSpokeConnector.MERKLE()), _merkle);
    assertEq(address(scrollSpokeConnector.watcherManager()), watcherManager);
    assertEq(scrollSpokeConnector.forTest_gasCap(), _gasCap);
  }
}

contract ScrollSpokeConnector_RenounceOwnership is Base {
  function test_revertIfCallerNotOwner(address _caller) public {
    vm.assume(_caller != owner);
    vm.prank(_caller);
    vm.expectRevert(ProposedOwnable.ProposedOwnable__onlyOwner_notOwner.selector);
    scrollSpokeConnector.renounceOwnership();
  }

  function test_ownerShouldntBeAbleToRenounce() public {
    vm.prank(owner);
    scrollSpokeConnector.renounceOwnership();
    assertEq(scrollSpokeConnector.owner(), owner);
  }
}

contract ScrollSpokeConnector_SendMessage is Base {
  function test_revertIfDataIsNot32Length(bytes memory _data) public {
    vm.assume(_data.length != 32);
    bytes memory _encodedData = "";

    vm.prank(user);
    vm.expectRevert(ScrollSpokeConnector.ScrollSpokeConnector_LengthIsNot32.selector);
    scrollSpokeConnector.forTest_sendMessage(_data, _encodedData);
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
        scrollSpokeConnector.ZERO_MSG_VALUE(),
        _functionCall,
        _gasCap
      ),
      ""
    );

    vm.prank(user);
    scrollSpokeConnector.forTest_sendMessage(_data, _encodedData);
  }
}

contract ScrollSpokeConnector_ProcessMessage is Base {
  event AggregateRootReceived(bytes32 _root);

  function test_revertIfSenderIsNotAMB(address _sender) public {
    vm.assume(_sender != _amb);
    bytes memory _data = _convertbytes32ToBytes(rootSnapshot);

    vm.prank(_sender);
    vm.expectRevert();
    scrollSpokeConnector.processMessage(_data);
  }

  function test_revertIfDataIsNot32Length(bytes memory _data) public {
    vm.assume(_data.length != 32);
    vm.prank(_amb);
    vm.expectRevert(ScrollSpokeConnector.ScrollSpokeConnector_LengthIsNot32.selector);
    scrollSpokeConnector.processMessage(_data);
  }

  function test_revertIfFromIsNotMirrorConnector() public {
    bytes memory _data = _convertbytes32ToBytes(rootSnapshot);
    // Mock the x domain message sender to be a stranger and not the mirror connector
    vm.mockCall(_amb, abi.encodeWithSelector(IScrollMessenger.xDomainMessageSender.selector), abi.encode(stranger));

    vm.prank(_amb);
    vm.expectRevert(ScrollSpokeConnector.ScrollSpokeConnector_OriginSenderIsNotMirrorConnector.selector);
    scrollSpokeConnector.processMessage(_data);
  }

  function test_callReceiveAggregateRoot() public {
    // Mock the root to a real one
    bytes memory _data = _convertbytes32ToBytes(aggregateRoot);

    // Mock the x domain message sender as if it is the mirror connector
    address _mirrorConnector = scrollSpokeConnector.mirrorConnector();
    vm.mockCall(
      _amb,
      abi.encodeWithSelector(IScrollMessenger.xDomainMessageSender.selector),
      abi.encode(_mirrorConnector)
    );

    // Expect AggregateRootReceived to be emitted
    vm.expectEmit(true, true, true, true);
    emit AggregateRootReceived(aggregateRoot);

    vm.prank(_amb);
    scrollSpokeConnector.processMessage(_data);
  }
}

contract ScrollSpokeConnector_VerifySender is Base {
  function test_returnFalseIfOriginSenderNotMirror(address _originSender, address _mirrorConnector) public {
    vm.assume(_originSender != _mirrorConnector);
    vm.mockCall(
      _amb,
      abi.encodeWithSelector(IScrollMessenger.xDomainMessageSender.selector),
      abi.encode(_originSender)
    );
    assertEq(scrollSpokeConnector.forTest_verifySender(_mirrorConnector), false);
  }

  function test_returnTrueIfOriginSenderIsMirror(address _mirrorConnector) public {
    vm.mockCall(
      _amb,
      abi.encodeWithSelector(IScrollMessenger.xDomainMessageSender.selector),
      abi.encode(_mirrorConnector)
    );
    vm.prank(_mirrorConnector);
    assertEq(scrollSpokeConnector.forTest_verifySender(_mirrorConnector), true);
  }
}
