// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.17;

import {BaseScroll} from "../../../../../../contracts/messaging/connectors/scroll/BaseScroll.sol";
import {Connector} from "../../../../../../contracts/messaging/connectors/Connector.sol";
import {ConnectorHelper} from "../../../../../utils/ConnectorHelper.sol";
import {ScrollSpokeConnector} from "../../../../../../contracts/messaging/connectors/scroll/scrollSpokeConnector.sol";
import {MerkleTreeManager} from "../../../../../../contracts/messaging/MerkleTreeManager.sol";
import {ProposedOwnable} from "../../../../../../contracts/shared/ProposedOwnable.sol";
import {IScrollMessenger} from "../../../../../../contracts/messaging/interfaces/ambs/scroll/IScrollMessenger.sol";
import {RootManager} from "../../../../../../contracts/messaging/RootManager.sol";
import {WatcherManager} from "../../../../../../contracts/messaging/WatcherManager.sol";

contract Common is ConnectorHelper {
  uint256 internal constant _FORK_BLOCK = 815_854;
  IScrollMessenger public constant L2_SCROLL_MESSENGER = IScrollMessenger(0x781e90f1c8Fc4611c9b7497C3B47F99Ef6969CbC); // Scroll Messenger L2 Proxy address
  address public constant L1_SCROLL_MESSENGER = 0x7885BcBd5CeCEf1336b5300fb5186A12DDD8c478;

  address public owner = makeAddr("owner");
  address public user = makeAddr("user");
  address public whitelistedWatcher = makeAddr("whitelistedWatcher");

  ScrollSpokeConnector public scrollSpokeConnector;
  uint32 public constant MIRROR_DOMAIN = 1; // Etherem
  uint32 public constant DOMAIN = 2; // Scroll
  RootManager public rootManager;
  address public mirrorConnector = makeAddr("mirrorConnector");
  uint256 public constant DELAY_BLOCKS = 0;
  MerkleTreeManager public merkleTreeManager;
  WatcherManager public watcherManager;
  uint256 public gasCap;

  function setUp() public {
    // TODO: move to an env (find where to place in the monorepo)
    vm.createSelectFork(vm.rpcUrl("https://1rpc.io/scroll"), _FORK_BLOCK);

    vm.startPrank(owner);
    // Deploy mekrle tree manager (needed in root manager)
    merkleTreeManager = new MerkleTreeManager();

    // Deploy watcher manager (needed in root manager)
    watcherManager = new WatcherManager();
    // Add a watcher (need for setting the slow mode)
    watcherManager.addWatcher(whitelistedWatcher);

    // Deploy root manager (needed in scroll spoke connector)
    uint256 _minDisputeBlocks = 1;
    uint256 _disputeBlocks = 10;
    rootManager = new RootManager(
      DELAY_BLOCKS,
      address(merkleTreeManager),
      address(watcherManager),
      _minDisputeBlocks,
      _disputeBlocks
    );

    scrollSpokeConnector = new ScrollSpokeConnector(
      DOMAIN,
      MIRROR_DOMAIN,
      address(L2_SCROLL_MESSENGER),
      address(rootManager),
      mirrorConnector,
      _processGas,
      _reserveGas,
      DELAY_BLOCKS,
      address(merkleTreeManager),
      address(watcherManager),
      gasCap
    );

    vm.stopPrank();
    // Set root manager as slow mode so the L2_SCROLL_MESSENGER messages can be received
    vm.prank(whitelistedWatcher);
    rootManager.activateSlowMode();
  }
}
