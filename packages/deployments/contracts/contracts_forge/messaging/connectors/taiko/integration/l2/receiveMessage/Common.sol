// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ConnectorHelper} from "../../../../../../utils/ConnectorHelper.sol";
import {MerkleTreeManager} from "../../../../../../../contracts/messaging/MerkleTreeManager.sol";
import {ProxiedBridge} from "./forTest/Bridge.sol";
import {RootManager} from "../../../../../../../contracts/messaging/RootManager.sol";
import {SpokeConnector} from "../../../../../../../contracts/messaging/connectors/SpokeConnector.sol";
import {TaikoSpokeConnector} from "../../../../../../../contracts/messaging/connectors/taiko/TaikoSpokeConnector.sol";
import {WatcherManager} from "../../../../../../../contracts/messaging/WatcherManager.sol";

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
  address public BRIDGE = 0x1000777700000000000000000000000000000004;
  // Address manager on Taiko L2
  address public ADDRESS_MANAGER = 0x1000777700000000000000000000000000000006;
  // `to` address on the messages sent on sepolia, used as mirror connector on the tests
  address public MIRROR_CONNECTOR = 0xC7501687169b955FAFe10bb9Cd1a1a8FeF8Db1D1;

  // EOAs and external addresses
  address public owner = makeAddr("owner");
  address public user = makeAddr("user");
  address public relayer = makeAddr("relayer");
  address public whitelistedWatcher = makeAddr("whitelistedWatcher");

  // Taiko Bridge instance
  ProxiedBridge public bridge;

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

    // Deploy the taiko bridge
    bridge = new ProxiedBridge();
    // Overwrite the taiko bridge address with the recently deployed Bridge contract
    vm.etch(BRIDGE, address(bridge).code);
    // Update the bridge instance with the new address
    bridge = ProxiedBridge(payable(BRIDGE));
    vm.stopPrank();

    // Set the address manager to the Taiko's address manager
    vm.prank(bridge.owner());
    bridge.setAddressManager(ADDRESS_MANAGER);

    // Deploy scroll hub connector
    vm.startPrank(owner);
    _gasCap = 200_000;
    SpokeConnector.ConstructorParams memory _constructorParams = SpokeConnector.ConstructorParams(
      DOMAIN,
      MIRROR_DOMAIN,
      address(bridge),
      address(rootManager),
      MIRROR_CONNECTOR,
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
