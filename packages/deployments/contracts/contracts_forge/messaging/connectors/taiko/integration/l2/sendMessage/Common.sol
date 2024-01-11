// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ConnectorHelper} from "../../../../../../utils/ConnectorHelper.sol";
import {MerkleTreeManager} from "../../../../../../../contracts/messaging/MerkleTreeManager.sol";
import {RootManager} from "../../../../../../../contracts/messaging/RootManager.sol";
import {SpokeConnector} from "../../../../../../../contracts/messaging/connectors/SpokeConnector.sol";
import {TaikoSpokeConnector} from "../../../../../../../contracts/messaging/connectors/taiko/TaikoSpokeConnector.sol";
import {WatcherManager} from "../../../../../../../contracts/messaging/WatcherManager.sol";
import {IBridge} from "../../../../../../../contracts/messaging/interfaces/ambs/taiko/IBridge.sol";

contract Common is ConnectorHelper {
  uint256 internal constant _FORK_BLOCK = 2_309_432;

  // Chains id
  uint256 public constant TAIKO_CHAIN_ID = 167007;
  uint256 public constant SEPOLIA_CHAIN_ID = 11155111;
  // Taiko domain id for Connext
  uint32 public constant DOMAIN = 101;
  // Sepolia domain id for Connext
  uint32 public constant MIRROR_DOMAIN = 20;
  // Bridge address on Taiko L2
  IBridge public BRIDGE = IBridge(0x1000777700000000000000000000000000000004);

  // EOAs and external addresses
  address public owner = makeAddr("owner");
  address public user = makeAddr("user");
  address public mirrorConnector = makeAddr("mirrorConnector");

  // Connext Contracts
  TaikoSpokeConnector public taikoSpokeConnector;
  RootManager public rootManager;
  MerkleTreeManager public merkleTreeManager;
  WatcherManager public watcherManager;

  /**
   * on the root manager so root messages can be received.
   */
  function setUp() public {
    vm.createSelectFork(vm.rpcUrl(vm.envString("TAIKO_RPC")), _FORK_BLOCK);

    vm.startPrank(owner);
    // Deploy merkle tree manager (needed in root manager)
    merkleTreeManager = new MerkleTreeManager();

    // Deploy watcher manager (needed in root manager)
    watcherManager = new WatcherManager();

    // Deploy root manager
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

    // Deploy taiko spoke connector
    _gasCap = 200_000;
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

    // Add the taiko spoke connector as a new supported on the mirror domain
    rootManager.addConnector(MIRROR_DOMAIN, address(taikoSpokeConnector));
    vm.stopPrank();
  }
}
