// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IConnectorManager} from '../messaging/interfaces/IConnectorManager.sol';
import {IBaseConnext} from './interfaces/IBaseConnext.sol';

/**
 * @notice THIS FILE DEFINES OUR STORAGE LAYOUT AND ID GENERATION SCHEMA. IT CAN ONLY BE MODIFIED FREELY FOR FRESH
 * DEPLOYS. If you are modifiying this file for an upgrade, you must **CAREFULLY** ensure
 * the contract storage layout is not impacted.
 *
 * BE VERY CAREFUL MODIFYING THE VALUES IN THIS FILE!
 */
abstract contract ConnextStorage is IBaseConnext {
  //
  // 0
  address public owner;

  /**
   * @notice Initialization flag.
   */
  // 0
  bool public initialized;

  /**
   * @notice The delay period before a new owner can be accepted.
   */
  // 1
  uint256 public acceptanceDelay;

  /**
   * @notice The numerator for the liquidity fee.
   */
  // 2
  uint256 public LIQUIDITY_FEE_NUMERATOR;

  /**
   * @notice The local address that is custodying relayer fees.
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

  /**
   * @notice Mapping of asset addresses to the canonical token ids.
   */
  // 6
  // (address _asset => bytes32 _canonical);
  mapping(address => TokenId) assetToCanonical;

  /**
   * @notice Mapping of the ticker hashes to the domains they are supported on.
   */
  // 7
  // (bytes32 _tickerHash => mapping(uint32 _domain => bool _supported));
  mapping(bytes32 => mapping(uint32 => bool)) public supportedAssetDomains;

  /**
   * @notice Mapping of ticker hashes to the fee configuration.
   */
  // 8
  // bytes32 _tickerHash => FeeConfig
  mapping(bytes32 => FeeConfig) public feeConfig;

  /**
   * @notice Mapping of ticker hashes to the asset addresses.
   */
  // 9
  // (bytes32 _tickerHash => address _assetId);
  mapping(bytes32 => address) public tickerHashToAssetId;

  /**
   * @notice Mapping of asset addresses to the ticker hashes.
   */
  // 10
  // (address _assetId => bytes32 _tickerHash);
  mapping(address => bytes32) public assetIdToTickerHash;

  /**
   * @notice Mapping of canonicalIds to the token configs.
   */
  // 11
  // (bytes32 _canonicalId => TokenConfig config);
  mapping(bytes32 => TokenConfig) public tokenConfigs;

  /**
   * @notice Mapping to track transfer status on destination and reconciliation domains
   */
  // 12
  // (bytes32 _domain => TransferStatus _status);
  mapping(bytes32 => TransferStatus) public transferStatus;

  /**
   * @notice Mapping holding router address that provided fast liquidity.
   */
  // 13
  // (bytes32 _transferId => address[] _routers);
  mapping(bytes32 => address[]) public routedTransfers;

  /**
   * @notice Mapping of asset ids to the unclaimed amounts.
   */
  // 14
  // (address _assetId => uint256 _amount);
  mapping(address => uint256) public unclaimedAssets;

  /**
   * @notice Mapping of router to available balance of an asset.
   * @dev Routers should always store liquidity that they can expect to receive via the bridge on
   * this domain (the local asset).
   */
  // 15
  // (address _router => mapping(address _assetId => uint256 _amount));
  mapping(address => mapping(address => uint256)) public routerBalances;

  /**
   * @notice Mapping of the amount of credits of the routers.
   */
  // 16
  // (address _assetId => mapping(address _router => uint256 _amount));
  mapping(address => mapping(address => uint256)) public credits;

  /**
   * @notice The max amount of routers a payment can be routed through.
   */
  // 17
  uint256 public maxRoutersPerTransfer;

  /**
   * @notice Stores a mapping of remote routers keyed on domains.
   * @dev Addresses are cast to bytes32.
   * This mapping is required because the Connext now contains the BridgeRouter and must implement
   * the remotes interface.
   */
  // 18
  // (uint32 _domain => bytes32 _router);
  mapping(uint32 => bytes32) public remotes;

  /**
   * @notice The proposed owner for the contract.
   */
  // 19
  address public proposedOwner;

  /**
   * @notice The timestamp when a new owner was proposed.
   */
  // 20
  uint256 public proposedOwnershipTimestamp;

  /**
   * @notice Stores whether or not the router allowlist has been removed.
   */
  // 21
  bool public routerAllowlistRemoved;

  /**
   * @notice The timestamp when the router allowlist was proposed to be removed.
   */
  // 22
  uint256 public routerAllowlistTimestamp;

  /**
   * @notice Mapping of addresses to Roles.
   * @dev returns uint representing the enum Role value.
   */
  // 23
  // (address _account => Role _role);
  mapping(address => Role) public roles;

  /**
   * @notice Mapping of router configurations.
   */
  // 24
  // (address _router => RouterConfig _config);
  mapping(address => RouterConfig) public routerConfigs;

  /**
   * @notice Reentracy flag for nonReentrant calls.
   */
  // 25
  uint256 internal _status;

  /**
   * @notice Reentrancy flag for nonXCallReentrant xcalls.
   */
  // 26
  uint256 internal _xcallStatus;

  /**
   * @notice Stores whether or not bribing, AMMs, have been paused.
   */
  // 27
  bool internal _paused;

  /**
   * @notice Remote connection manager for xapp.
   */
  // 27
  IConnectorManager public xAppConnectionManager;
}
