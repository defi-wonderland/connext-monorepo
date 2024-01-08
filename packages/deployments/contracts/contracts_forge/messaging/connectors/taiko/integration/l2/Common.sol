// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {Connector} from "../../../../../../contracts/messaging/connectors/Connector.sol";
import {ConnectorHelper} from "../../../../../utils/ConnectorHelper.sol";
import {MerkleTreeManager} from "../../../../../../contracts/messaging/MerkleTreeManager.sol";
import {RootManager} from "../../../../../../contracts/messaging/RootManager.sol";
import {SpokeConnector} from "../../../../../../contracts/messaging/connectors/SpokeConnector.sol";
import {TaikoSpokeConnector} from "../../../../../../contracts/messaging/connectors/taiko/TaikoSpokeConnector.sol";
import {WatcherManager} from "../../../../../../contracts/messaging/WatcherManager.sol";
import {IBridge} from "../../../../../../contracts/messaging/interfaces/ambs/taiko/IBridge.sol";
import {console} from "forge-std/Test.sol";

contract Common is ConnectorHelper {
  uint256 internal constant _FORK_BLOCK = 1_359_432;

  uint256 public constant SEPOLIA_CHAIN_ID = 11155111;
  // Taiko domain id for Connext
  uint32 public constant DOMAIN = 101;
  // Sepolia domain id for Connext
  uint32 public constant MIRROR_DOMAIN = 20;

  // Bridge contract on Taiko
  IBridge public constant BRIDGE = IBridge(0x1000777700000000000000000000000000000004);

  // EOAs and external addresses
  address public owner = makeAddr("owner");
  address public user = makeAddr("user");
  address public relayer = makeAddr("relayer");
  address public whitelistedWatcher = makeAddr("whitelistedWatcher");
  address public mirrorConnector = makeAddr("mirrorConnector");

  // Connext Contracts
  TaikoSpokeConnector public taikoSpokeConnector;
  RootManager public rootManager;
  MerkleTreeManager public merkleTreeManager;
  WatcherManager public watcherManager;

  /**
   * @notice Deploys the merkle tree manager, adds a watcher, deploys the root manager and the taiko spoke connector.
   * It also adds the taiko spoke connector as a new supported domain in the root manager and finally it activates the slow mode
   * on the root manager so root messages can be received.
   */
  function setUp() public {
    vm.createSelectFork(vm.rpcUrl(vm.envString("TAIKO_RPC")), _FORK_BLOCK);

    vm.startPrank(owner);
    // Deploy merkle tree manager (needed in root manager)
    merkleTreeManager = new MerkleTreeManager();

    // Deploy watcher manager (needed in root manager)
    watcherManager = new WatcherManager();
    // Add a watcher (need for setting the slow mode)
    watcherManager.addWatcher(whitelistedWatcher);

    // Deploy root manager (needed in scroll spoke connector)
    uint256 _minDisputeBlocks = 1;
    uint256 _disputeBlocks = 10;
    uint256 _delayBlocks = 0;
    rootManager = new RootManager(
      _delayBlocks,
      address(merkleTreeManager),
      address(watcherManager),
      _minDisputeBlocks,
      _disputeBlocks
    );

    // Deploy scroll hub connector
    SpokeConnector.ConstructorParams memory _constructorParams = SpokeConnector.ConstructorParams(
      DOMAIN,
      MIRROR_DOMAIN,
      address(BRIDGE),
      address(rootManager),
      mirrorConnector,
      _processGas,
      _reserveGas,
      _delayBlocks,
      address(merkleTreeManager),
      address(watcherManager),
      _minDisputeBlocks,
      _disputeBlocks
    );
    taikoSpokeConnector = new TaikoSpokeConnector(_constructorParams, SEPOLIA_CHAIN_ID, _gasCap);

    // Add connector as a new supported domain
    rootManager.addConnector(MIRROR_DOMAIN, address(taikoSpokeConnector));
    vm.stopPrank();
  }
}
