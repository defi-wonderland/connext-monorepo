// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {Connector} from "../../../../../../contracts/messaging/connectors/Connector.sol";
import {ConnectorHelper} from "../../../../../utils/ConnectorHelper.sol";
import {MerkleTreeManager} from "../../../../../../contracts/messaging/MerkleTreeManager.sol";
import {RootManager} from "../../../../../../contracts/messaging/RootManager.sol";
import {TaikoHubConnector} from "../../../../../../contracts/messaging/connectors/taiko/TaikoHubConnector.sol";
import {WatcherManager} from "../../../../../../contracts/messaging/WatcherManager.sol";
import {IBridge} from "../../../../../../contracts/messaging/interfaces/ambs/taiko/IBridge.sol";
import {console} from "forge-std/Test.sol";

contract Common is ConnectorHelper {
  uint256 public constant FORK_BLOCK = 5_024_712;
  // uint256 public constant FORK_BLOCK = 5_024_855;

  uint256 public constant TAIKO_CHAIN_ID = 167007;
  // Sepolia domain id for Connext
  uint32 public constant DOMAIN = 20;
  // Taiko domain id for Connext
  uint32 public constant MIRROR_DOMAIN = 101;

  // Bride contract on Sepolia
  IBridge public constant BRIDGE = IBridge(0x5293Bb897db0B64FFd11E0194984E8c5F1f06178);
  address public constant RECIPIENT = 0xC7501687169b955FAFe10bb9Cd1a1a8FeF8Db1D1;
  address public constant MIRROR_CONNECTOR = 0x0006e19078A46C296eb6b44d37f05ce926403A82;

  // EOAs and external addresses
  address public owner = makeAddr("owner");
  address public relayer = makeAddr("relayer");
  address public whitelistedWatcher = makeAddr("whitelistedWatcher");

  // Connext Contracts
  TaikoHubConnector public taikoHubConnector;
  RootManager public rootManager;
  MerkleTreeManager public merkleTreeManager;
  WatcherManager public watcherManager;

  /**
   * @notice Deploys the merkle tree manager, adds a watcher, deploys the root manager and the taiko spoke connector.
   * It also adds the taiko spoke connector as a new supported domain in the root manager and finally it activates the slow mode
   * on the root manager so root messages can be received.
   */
  function setUp() public {
    vm.createSelectFork(vm.rpcUrl(vm.envString("SEPOLIA_RPC")), FORK_BLOCK);

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
    taikoHubConnector = new TaikoHubConnector(
      DOMAIN,
      MIRROR_DOMAIN,
      address(BRIDGE),
      address(rootManager),
      MIRROR_CONNECTOR,
      address(BRIDGE),
      TAIKO_CHAIN_ID,
      _gasCap
    );

    bytes memory _bytecode = address(taikoHubConnector).code;
    // Set the bytecode on the recipient address
    vm.etch(RECIPIENT, _bytecode);
    // Set the fuel hub connector instance to the recipient address after deployment
    taikoHubConnector = TaikoHubConnector(payable(RECIPIENT));

    vm.stopPrank();
    vm.startPrank(taikoHubConnector.owner());
    taikoHubConnector.setGasCap(_gasCap);
    taikoHubConnector.setMirrorConnector(MIRROR_CONNECTOR);
    vm.stopPrank();

    // Add connector as a new supported domain
    vm.prank(owner);
    rootManager.addConnector(MIRROR_DOMAIN, address(taikoHubConnector));
  }
}
