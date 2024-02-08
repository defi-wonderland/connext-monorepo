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
  // 0
  address public owner;

  // 0
  bool public initialized;

  // 1
  uint256 public acceptanceDelay;

  uint256 LIQUIDITY_FEE_NUMERATOR;

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

  // 5
  // (address _asset => bytes32 _canonicalId);
  mapping(address => bytes32) public assetCanonicalIds;

  // 6
  // (bytes32 _tickerHash => mapping(uint32 _domain => bool _supported));
  mapping(bytes32 => mapping(uint32 => bool)) public supportedAssetDomains;

  // 7
  // (bytes32 _tickerHash => mapping(bytes _path => address _strategy));
  mapping(bytes32 => mapping(bytes => address)) public settlementStrategies;

  // 8
  // mapping(bytes32 _tickerHash => struct FeeConfig) public feeConfig; // TODO: define fee config struct

  // Assets - reverse lookups
  // 9
  // (bytes32 _tickerHash => address _nextAsset);
  mapping(bytes32 => address) public tickerHashToNextAsset; // TODO: check

  // 10
  // (bytes32 _tickerHash => address _assetId);
  mapping(bytes32 => address) public tickerHashToAssetId; // TODO: check

  // 11
  // (address _nextAsset => bytes32 _tickerHash);
  mapping(address => bytes32) public nextAssetToTickerHash; // TODO: check

  // 12
  // (address _assetId => bytes32 _tickerHash);
  mapping(address => bytes32) public assetIdToTickerHash; // TODO: check

  // 13
  // (bytes32 _canonicalId => TokenConfig config);
  mapping(bytes32 => TokenConfig) public tokenConfigs;

  /**
   * @notice Mapping to track transfer status on destination domain
   */
  // 14
  // (bytes32 _domain => DestinationTransferStatus _status);
  mapping(bytes32 => DestinationTransferStatus) public transferStatus;

  /**
   * @notice Mapping holding router address that provided fast liquidity.
   */
  // 15
  // (bytes32 _transferId => address[] _routers);
  mapping(bytes32 => address[]) public routedTransfers;

  // 16
  // (address _assetId => uint256 _amount);
  mapping(address => uint256) public unclaimedAssets;

  /**
   * @notice Mapping of router to available balance of an asset.
   * @dev Routers should always store liquidity that they can expect to receive via the bridge on
   * this domain (the local asset).
   */
  // 17
  // (address _router => mapping(address _assetId => uint256 _amount));
  mapping(address => mapping(address => uint256)) public routerBalances;

  // 18
  // (address _assetId => mapping(address _router => uint256 _amount));
  mapping(address => mapping(address => uint256)) public routerCredits;

  /**
   * @notice Mapping of approved relayers
   * @dev Send relayer fee if msg.sender is approvedRelayer; otherwise revert.
   */
  // 19
  // (address _relayer => bool _approved);
  mapping(address => bool) public approvedRelayers;
  /**
   * @notice The max amount of routers a payment can be routed through.
   */
  // 20
  uint256 public maxRoutersPerTransfer;

  /**
   * @notice Stores a mapping of remote routers keyed on domains.
   * @dev Addresses are cast to bytes32.
   * This mapping is required because the Connext now contains the BridgeRouter and must implement
   * the remotes interface.
   */
  // 21
  // (uint32 _domain => bytes32 _router);
  mapping(uint32 => bytes32) public remotes;

  //
  // ProposedOwnable
  //
  // 22
  address public proposed;

  // 23
  uint256 public proposedOwnershipTimestamp;

  // 24
  bool public routerAllowlistRemoved;

  // 26
  uint256 public routerAllowlistTimestamp;

  /**
   * @notice Stores a mapping of address to Roles
   * @dev returns uint representing the enum Role value
   */
  // 26
  // (address _account => Role _role);
  mapping(address => Role) public roles;

  //
  // RouterFacet
  //
  // 27
  // (address _router => RouterConfig _config);
  mapping(address => RouterConfig) public routerConfigs;

  //
  // ReentrancyGuard
  //
  // 28
  uint256 internal _status;

  // 29
  uint256 internal _xcallStatus;

  /**
   * @notice Stores whether or not bribing, AMMs, have been paused.
   */
  // 30
  bool internal _paused;

  // 31
  // (address _sequencer => bool _approved);
  mapping(address => bool) public approvedSequencers;

  /**
   * @notice Remote connection manager for xapp.
   */
  // 32
  IConnectorManager public xAppConnectionManager;
}
