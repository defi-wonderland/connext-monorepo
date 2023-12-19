// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.17;

import {BaseTaiko} from "../../../../../contracts/messaging/connectors/taiko/BaseTaiko.sol";
import {Connector} from "../../../../../contracts/messaging/connectors/Connector.sol";
import {ConnectorHelper} from "../../../../utils/ConnectorHelper.sol";
import {ISignalService} from "../../../../../contracts/messaging/interfaces/ambs/taiko/ISignalService.sol";

/**
 * @dev For test contract to access internal functions of `BaseTaiko`
 */
contract BaseTaikoForTest is BaseTaiko {
  constructor(address _taikoSignalService) BaseTaiko(_taikoSignalService) {}

  function forTest_checkMessageLength(bytes memory _data) external pure returns (bool _isValid) {
    _isValid = _checkMessageLength(_data);
  }

  function forTest_sendSignal(bytes32 _signal) external {
    _sendSignal(_signal);
  }

  function forTest_verifyAndGetSignal(
    uint256 _sourceChainId,
    address _mirrorConnector,
    bytes memory _data
  ) external view returns (bool _isReceived, bytes32 _signal) {
    (_isReceived, _signal) = _verifyAndGetSignal(_sourceChainId, _mirrorConnector, _data);
  }
}

/**
 * @dev Base contract for the `BaseTaiko` unit tests contracts to inherit from
 */
contract Base is ConnectorHelper {
  // The root length in bytes for a message
  uint256 public constant ROOT_LENGTH = 32;

  address public user = makeAddr("user");
  address public offChainAgent = makeAddr("offChainAgent");
  address public signalService = makeAddr("SignalService");
  BaseTaikoForTest public baseTaiko;

  /**
   * @notice Deploys a new `BaseTaikoForTest` contract instance
   */
  function setUp() public {
    baseTaiko = new BaseTaikoForTest(signalService);
  }
}

contract Unit_Connector_BaseTaiko_Constructor is Base {
  function test_checkConstructorArgs() public {
    assertEq(address(baseTaiko.TAIKO_SIGNAL_SERVICE()), signalService);
  }
}

contract Unit_Connector_BaseTaiko_CheckMessageLength is Base {
  /**
   * @notice Tests that reverts when called with invalid length data
   * @param _data Message data
   */
  function test_returnFalseOnInvalidLength(bytes memory _data) public {
    vm.assume(_data.length != ROOT_LENGTH);
    assertEq(baseTaiko.forTest_checkMessageLength(_data), false);
  }

  /**
   * @notice Tests that returns true on data valid length
   */
  function test_checkMessageLength() public {
    bytes memory _data = new bytes(ROOT_LENGTH);
    assertEq(baseTaiko.forTest_checkMessageLength(_data), true);
  }
}

contract Unit_Connector_BaseTaiko_sendMessage is Base {
  /**
   * @notice Tests that `sendSignal` function is called correctly
   * @param _signal The signal (or message) to send
   * @param _storageSlotResponse The storage slot response of the `sendSignal` call
   */
  function test_callSendSignal(bytes32 _signal, bytes32 _storageSlotResponse) public {
    // Mock the call over `sendSignal` and expect it to be called
    _mockAndExpect(
      signalService,
      abi.encodeWithSelector(ISignalService.sendSignal.selector, _signal),
      abi.encode(_storageSlotResponse)
    );
    // Call `sendSignal` function
    vm.prank(user);
    baseTaiko.forTest_sendSignal(_signal);
  }
}

contract Unit_Connector_BaseTaiko_VerifyAndGetSignal is Base {
  /**
   * @notice Mocks the call over `verifyAndGetSignal` and expect it to be called
   * @dev It also starts the prank on the offChainAgent
   * @param _sourceChainId The source chain id
   * @param _mirrorConnector The mirror connector address
   * @param _signal The signal (or message) to send
   * @param _proof The proof of the signal sent
   * @param _received Whether the signal was received or not
   */
  modifier happyPath(
    uint256 _sourceChainId,
    address _mirrorConnector,
    bytes32 _signal,
    bytes memory _proof,
    bool _received
  ) {
    _mockAndExpect(
      signalService,
      abi.encodeWithSelector(
        ISignalService.isSignalReceived.selector,
        _sourceChainId,
        _mirrorConnector,
        _signal,
        _proof
      ),
      abi.encode(_received)
    );
    vm.startPrank(offChainAgent);
    _;
  }

  /**
   * @notice Tests that `isSignalReceived` function is called correctly
   * @param _sourceChainId The source chain id
   * @param _mirrorConnector The mirror connector address
   * @param _signal The signal (or message) to send
   * @param _proof The proof of the signal sent
   * @dev It uses the `happyPath` modifier setting `_received` to true
   */
  function test_callIsSignalReceived(
    uint256 _sourceChainId,
    address _mirrorConnector,
    bytes32 _signal,
    bytes memory _proof
  ) public happyPath(_sourceChainId, _mirrorConnector, _signal, _proof, true) {
    // Call `verifyAndGetSignal` function
    bytes memory _data = abi.encode(_signal, _proof);
    baseTaiko.forTest_verifyAndGetSignal(_sourceChainId, _mirrorConnector, _data);
  }

  /**
   * @notice Tests the returned values of `verifyAndGetSignal` function based on `_received` value
   * @param _sourceChainId The source chain id
   * @param _mirrorConnector The mirror connector address
   * @param _signal The signal (or message) to send
   * @param _proof The proof of the signal sent
   * @param _isReceived Whether the signal was received or not
   */
  function test_returnVars(
    uint256 _sourceChainId,
    address _mirrorConnector,
    bytes32 _signal,
    bytes memory _proof,
    bool _isReceived
  ) public happyPath(_sourceChainId, _mirrorConnector, _signal, _proof, _isReceived) {
    // Call `verifyAndGetSignal` function
    bytes memory _data = abi.encode(_signal, _proof);
    (bool _actualIsReceived, bytes32 _actualSignal) = baseTaiko.forTest_verifyAndGetSignal(
      _sourceChainId,
      _mirrorConnector,
      _data
    );

    // Assert the returned values are correct
    assertEq(_actualIsReceived, _isReceived);
    assertEq(_actualSignal, _signal);
  }
}
