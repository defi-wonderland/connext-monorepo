// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IConnectorManager} from '../messaging/interfaces/IConnectorManager.sol';
import {TokenId, TokenConfig, DestinationTransferStatus, Role, RouterConfig} from './libraries/LibConnextStorage.sol';

/**
 * @notice THIS FILE DEFINES OUR STORAGE LAYOUT AND ID GENERATION SCHEMA. IT CAN ONLY BE MODIFIED FREELY FOR FRESH
 * DEPLOYS. If you are modifiying this file for an upgrade, you must **CAREFULLY** ensure
 * the contract storage layout is not impacted.
 *
 * BE VERY CAREFUL MODIFYING THE VALUES IN THIS FILE!
 */
abstract contract ConnextStorage {
  //
  // 0
  bool public initialized;

  // TODO: check slot new state var
  address public owner;

  // TODO: check slot new state var
  uint256 public acceptanceDelay;

  //
  // Connext
  //
  // 1
  // uint256 LIQUIDITY_FEE_NUMERATOR; // removed
  /**
   * @notice The local address that is custodying relayer fees
   */
  // 2
  address public relayerFeeVault;
  /**
   * @notice Nonce for the contract, used to keep unique transfer ids.
   * @dev Assigned at first interaction (xcall on origin domain).
   */
  // 3
  uint256 public nonce;
  /**
   * @notice The domain this contract exists on.
   * @dev Must match the domain identifier, which is distinct from the "chainId".
   */
  // 4
  uint32 public domain;
  /**
   * @notice Mapping of adopted to canonical asset information.
   */
  // 5
  // mapping(address => TokenId) adoptedToCanonical; // removed
  // asset => canonicalId
  mapping(address => bytes32) public assetCanonicalIds;

  // TODO: define slot
  // mapping(bytes32 _tickerHash => mapping(uint32 _domain => bool _supported))
  mapping(bytes32 => mapping(uint32 => bool)) public supportedAssetDomains;

  // TODO: define slot
  // mapping(bytes32 _tickerHash => mapping(bytes _path => address _strategy))
  mapping(bytes32 => mapping(bytes => address)) public settlementStrategies;

  // TODO: define slot
  // mapping(bytes32 _tickerHash => struct FeeConfig) public feeConfig; // TODO: define fee config struct

  // Assets - reverse lookups
  // TODO: define slots
  //mapping(bytes32 _tickerHash => address _nextAsset)
  mapping(bytes32 => address) public tickerHashToNextAsset;
  //mapping(bytes32 _tickerHash => address _assetId)
  mapping(bytes32 => address) public tickerHashToAssetId;

  // mapping(address _nextAsset => bytes32 _tickerHash)
  mapping(address => bytes32) public nextAssetToTickerHash;
  // mapping(address _assetId => bytes32 _tickerHash)
  mapping(address => bytes32) public assetIdToTickerHash;

  /**
   * @notice Mapping of representation to canonical asset information.
   */
  // 6
  // mapping(address => TokenId) representationToCanonical; // removed
  /**
   * @notice Mapping of hash(canonicalId, canonicalDomain) to token config on this domain.
   */
  // 7
  mapping(bytes32 => TokenConfig) public tokenConfigs;
  /**
   * @notice Mapping to track transfer status on destination domain
   */
  // 8
  mapping(bytes32 => DestinationTransferStatus) public transferStatus;
  /**
   * @notice Mapping holding router address that provided fast liquidity.
   */
  // 9
  mapping(bytes32 => address[]) public routedTransfers;
  /**
   * @notice Mapping of router to available balance of an asset.
   * @dev Routers should always store liquidity that they can expect to receive via the bridge on
   * this domain (the local asset).
   */
  // 10
  mapping(address => mapping(address => uint256)) public routerBalances;

  // TODO: define slot
  // mapping(address _assetId => uint256 _amount)
  mapping(address => uint256) public unclaimedAssets;

  // TODO: define slot
  // address _assetId => mapping(address _router => uint256 _amount)
  mapping(address => mapping(address => uint256)) public routerCredits;

  /**
   * @notice Mapping of approved relayers
   * @dev Send relayer fee if msg.sender is approvedRelayer; otherwise revert.
   */
  // 11
  mapping(address => bool) public approvedRelayers;
  /**
   * @notice The max amount of routers a payment can be routed through.
   */
  // 12
  uint256 public maxRoutersPerTransfer;
  /**
   * @notice Stores a mapping of transfer id to slippage overrides.
   */
  // 13
  // mapping(bytes32 => uint256) slippage; // removed
  /**
   * @notice Stores a mapping of transfer id to receive local overrides.
   */
  // 14
  mapping(bytes32 => bool) public receiveLocalOverride; // remove?
  /**
   * @notice Stores a mapping of remote routers keyed on domains.
   * @dev Addresses are cast to bytes32.
   * This mapping is required because the Connext now contains the BridgeRouter and must implement
   * the remotes interface.
   */
  // 15
  mapping(uint32 => bytes32) public remotes;
  //
  // ProposedOwnable
  //
  // 17
  address public proposed;
  // 18
  uint256 public proposedOwnershipTimestamp;
  // 19
  bool public routerAllowlistRemoved;
  // 20
  uint256 public routerAllowlistTimestamp;
  /**
   * @notice Stores a mapping of address to Roles
   * @dev returns uint representing the enum Role value
   */
  // 21
  mapping(address => Role) public roles;
  //
  // RouterFacet
  //
  // 22
  mapping(address => RouterConfig) public routerConfigs;
  //
  // ReentrancyGuard
  //
  // 23
  uint256 internal _status;
  // 24
  uint256 internal _xcallStatus;
  //
  // StableSwap
  //
  /**
   * @notice Mapping holding the AMM storages for swapping in and out of local assets
   * @dev Swaps for an adopted asset <> local asset (i.e. POS USDC <> nextUSDC on polygon)
   * Struct storing data responsible for automatic market maker functionalities. In order to
   * access this data, this contract uses SwapUtils library. For more details, see SwapUtils.sol.
   */
  // 25
  // mapping(bytes32 => SwapUtils.Swap) swapStorages; // removed
  /**
   * @notice Maps token address to an index in the pool. Used to prevent duplicate tokens in the pool.
   * @dev getTokenIndex function also relies on this mapping to retrieve token index.
   */
  // 26
  // mapping(bytes32 => mapping(address => uint8)) tokenIndexes; // removed
  /**
   * The address of an existing LPToken contract to use as a target
   * this target must be the address which connext deployed on this chain.
   */
  // 27
  // address lpTokenTargetAddress; // removed
  /**
   * @notice Stores whether or not bribing, AMMs, have been paused.
   */
  // 28
  bool internal _paused;
  //
  // AavePortals
  //
  /**
   * @notice Address of Aave Pool contract.
   */
  // 29
  //address aavePool; // TODO: remove
  /**
   * @notice Fee percentage numerator for using Portal liquidity.
   * @dev Assumes the same basis points as the liquidity fee.
   */
  // 30
  //uint256 aavePortalFeeNumerator; // TODO: remove
  /**
   * @notice Mapping to store the transfer liquidity amount provided by Aave Portals.
   */
  // 31
  //mapping(bytes32 => uint256) portalDebt; // TODO: remove
  /**
   * @notice Mapping to store the transfer liquidity amount provided by Aave Portals.
   */
  // 32
  //mapping(bytes32 => uint256) portalFeeDebt; // TODO: remove
  /**
   * @notice Mapping of approved sequencers
   * @dev Sequencer address provided must belong to an approved sequencer in order to call `execute`
   * for the fast liquidity route.
   */
  // 33
  mapping(address => bool) public approvedSequencers;
  /**
   * @notice Remote connection manager for xapp.
   */
  // 34
  IConnectorManager public xAppConnectionManager;
}
