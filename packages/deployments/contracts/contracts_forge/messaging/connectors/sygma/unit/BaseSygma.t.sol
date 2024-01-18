// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.17;

import {ConnectorHelper} from "../../../../utils/ConnectorHelper.sol";
import {BaseSygma} from "../../../../../contracts/messaging/connectors/sygma/BaseSygma.sol";
import {ISygmaConnector} from "../../../../../contracts/messaging/connectors/sygma/interfaces/ISygmaConnector.sol";
import {IBridge} from "../../../../../contracts/messaging/interfaces/ambs/sygma/IBridge.sol";

/**
 * @dev For test contract to access internal functions of `BaseSygma`
 */
contract BaseSygmaForTest is BaseSygma {
  constructor(
    address _amb,
    address _permissionlessHandler,
    uint256 _gasCap
  ) BaseSygma(_amb, _permissionlessHandler, _gasCap) {}
}

/**
 * @dev Base contract for the `BaseSygma` unit tests contracts to inherit from
 */
contract Base is ConnectorHelper {
  // The root length in bytes
  uint256 internal constant _ROOT_LENGTH = 32;
  bytes32 internal constant _PERMISSIONLESS_HANDLER_ID = bytes32(0);
  uint8 internal constant _ADDRESS_LEN = 20;
  address internal constant _ZERO_ADDRESS = address(0);
  uint16 internal constant _FUNCTION_SIG_LEN = uint16(4);
  // The function signature of the `receiveMessage` function
  bytes4 internal constant _FUNCTION_SIG = ISygmaConnector.receiveMessage.selector;

  address user = makeAddr("user");
  address permissionlessHandler = makeAddr("permissionlessHandler");
  IBridge public bridge = IBridge(makeAddr("Bridge"));
  BaseSygmaForTest public baseSygma;

  /**
   * @notice Deploys a new `BaseSygmaForTest` contract instance
   */
  function setUp() public {
    baseSygma = new BaseSygmaForTest(address(bridge), permissionlessHandler, _gasCap);
  }
}

contract Unit_Connector_BaseSygma_Constructor is Base {
  /**
   * @notice Tests the constants values are set correctly
   */
  function test_constants() public {
    assertEq(baseSygma.PERMISSIONLESS_HANDLER_ID(), _PERMISSIONLESS_HANDLER_ID);
    assertEq(baseSygma.ADDRESS_LEN(), _ADDRESS_LEN);
    assertEq(baseSygma.ZERO_ADDRESS(), _ZERO_ADDRESS);
    assertEq(baseSygma.FUNCTION_SIG_LEN(), _FUNCTION_SIG_LEN);
    assertEq(baseSygma.FUNCTION_SIG(), _FUNCTION_SIG);
  }

  /**
   * @notice Tests the constructor arguments are set correctly
   */
  function test_constructorArgs() public {
    assertEq(address(baseSygma.SYGMA_BRIDGE()), address(bridge));
    assertEq(baseSygma.PERMISSIONLESS_HANDLER(), permissionlessHandler);
    assertEq(baseSygma.gasCap(), _gasCap);
  }
}

contract Unit_Connector_BaseSygma_EncodeDepositData is Base {
  /**
   * @notice Tests it reverts when the root length is incorrect
   * @param _root The message's root
   * @param _mirrorConnector The address of the mirror connector
   */
  function test_encodeDepositData(bytes32 _root, address _mirrorConnector) public {
    bytes memory _expectedDepositData = abi.encodePacked(
      _gasCap,
      _FUNCTION_SIG_LEN,
      _FUNCTION_SIG,
      _ADDRESS_LEN,
      _mirrorConnector,
      _ADDRESS_LEN,
      address(baseSygma),
      _root
    );

    bytes memory _depositData = baseSygma.encodeDepositData(_root, _mirrorConnector);
    assertEq(_depositData, _expectedDepositData);
  }
}
