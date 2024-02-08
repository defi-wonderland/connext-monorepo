// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {IConnectorManager} from "../messaging/interfaces/IConnectorManager.sol";
import {TokenId, TokenConfig, DestinationTransferStatus, Role, RouterConfig} from "./libraries/LibConnextStorage.sol";

/**
 * @notice THIS FILE DEFINES OUR STORAGE LAYOUT AND ID GENERATION SCHEMA. IT CAN ONLY BE MODIFIED FREELY FOR FRESH
 * DEPLOYS. If you are modifiying this file for an upgrade, you must **CAREFULLY** ensure
 * the contract storage layout is not impacted.
 *
 * BE VERY CAREFUL MODIFYING THE VALUES IN THIS FILE!
 */
abstract contract ConnextStorage {

  // 0
  address public owner;

  // 1
  bool public initialized;

  // 2
  uint256 public acceptanceDelay;

  /**
   * @notice The local address that is custodying relayer fees
   */
  // 3
  address public relayerFeeVault;

  /**
   * @notice Nonce for the contract, used to keep unique transfer ids.
   * @dev Assigned at first interaction (xcall on origin domain).
   */
  // 4
  uint256 public nonce;

  /**
   * @notice The domain this contract exists on.
   * @dev Must match the domain identifier, which is distinct from the "chainId".
   */
  // 5
  uint32 public domain;

  // 6
  mapping(address _asset => bytes32 _canonicalId) public assetCanonicalIds;

  // 7
  mapping(bytes32 _tickerHash => mapping(uint32 _domain => bool _supported)) public supportedAssetDomains;

  // 8
  mapping(bytes32 _tickerHash => mapping(bytes _path => address _strategy)) public settlementStrategies;

  // 9
  // mapping(bytes32 _tickerHash => struct FeeConfig) public feeConfig; // TODO: define fee config struct

  // Assets - reverse lookups
  // 10
  mapping(bytes32 _tickerHash => address _nextAsset) public tickerHashToNextAsset;

  // 11
  mapping(bytes32 _tickerHash => address _assetId) public tickerHashToAssetId;

  // 12
  mapping(address _nextAsset => bytes32 _tickerHash) public nextAssetToTickerHash;

  // 13
  mapping(address _assetId => bytes32 _tickerHash) public assetIdToTickerHash;

  // 14
  mapping(bytes32 _canonicalId => TokenConfig) public tokenConfigs;

  /**
   * @notice Mapping to track transfer status on destination domain
   */
  // 15
  mapping(bytes32 _domain => DestinationTransferStatus _status) public transferStatus;

  /**
   * @notice Mapping holding router address that provided fast liquidity.
   */
  // 16
  mapping(bytes32 _transferId => address[] _routers) public routedTransfers;

  // 17
  mapping(address _assetId => uint256 _amount) public unclaimedAssets;

  /**
   * @notice Mapping of router to available balance of an asset.
   * @dev Routers should always store liquidity that they can expect to receive via the bridge on
   * this domain (the local asset).
   */
  // 18
  mapping(address _router => mapping(address _assetId => uint256 _amount)) public routerBalances;

  // 19
  mapping(address _assetId => mapping(address _router => uint256 _amount)) public routerCredits;

  /**
   * @notice Mapping of approved relayers
   * @dev Send relayer fee if msg.sender is approvedRelayer; otherwise revert.
   */
  // 20
  mapping(address _relayer => bool _approved) public approvedRelayers;
  /**
   * @notice The max amount of routers a payment can be routed through.
   */
  // 21
  uint256 public maxRoutersPerTransfer;

  /**
   * @notice Stores a mapping of transfer id to receive local overrides.
   */
  // 22
  mapping(bytes32 _transferId => bool _receives) public receiveLocalOverride; // remove?

  /**
   * @notice Stores a mapping of remote routers keyed on domains.
   * @dev Addresses are cast to bytes32.
   * This mapping is required because the Connext now contains the BridgeRouter and must implement
   * the remotes interface.
   */
  // 23
  mapping(uint32 _domain => bytes32 _router) public remotes;

  //
  // ProposedOwnable
  //
  // 24
  address public proposed;

  // 25
  uint256 public proposedOwnershipTimestamp;

  // 26
  bool public routerAllowlistRemoved;

  // 27
  uint256 public routerAllowlistTimestamp;

  /**
   * @notice Stores a mapping of address to Roles
   * @dev returns uint representing the enum Role value
   */
  // 28
  mapping(address _account => Role _role) public roles;

  //
  // RouterFacet
  //
  // 29
  mapping(address _router => RouterConfig _config) public routerConfigs;

  //
  // ReentrancyGuard
  //
  // 30
  uint256 internal _status;

  // 31
  uint256 internal _xcallStatus;

  /**
   * @notice Stores whether or not bribing, AMMs, have been paused.
   */
  // 32
  bool internal _paused;

  // 33
  mapping(address _sequencer => bool _approved) public approvedSequencers;

  /**
   * @notice Remote connection manager for xapp.
   */
  // 34
  IConnectorManager public xAppConnectionManager;

  //
  // Connext
  // uint256 LIQUIDITY_FEE_NUMERATOR; // removed
}
