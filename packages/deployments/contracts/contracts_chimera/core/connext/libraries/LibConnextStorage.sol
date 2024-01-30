// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import {IConnectorManager} from "../../../messaging/interfaces/IConnectorManager.sol";
import {TokenId} from "./TokenId.sol";

/**
 * @notice THIS FILE DEFINES OUR STORAGE LAYOUT AND ID GENERATION SCHEMA. IT CAN ONLY BE MODIFIED FREELY FOR FRESH
 * DEPLOYS. If you are modifiying this file for an upgrade, you must **CAREFULLY** ensure
 * the contract storage layout is not impacted.
 *
 * BE VERY CAREFUL MODIFYING THE VALUES IN THIS FILE!
 */

// ============= Enum =============

/// @notice Enum representing address role
// Returns uint
// None     - 0
// Router   - 1
// Watcher  - 2
// Admin    - 3
enum Role {
  None,
  RouterAdmin,
  Watcher,
  Admin
}

/**
 * @notice Enum representing status of destination transfer
 * @dev Status is only assigned on the destination domain, will always be "none" for the
 * origin domains
 * @return uint - Index of value in enum
 */
enum DestinationTransferStatus {
  None, // 0
  Reconciled, // 1
  Executed, // 2
  Completed // 3 - executed + reconciled
}

/**
 * @notice These are the parameters that will remain constant between the
 * two chains. They are supplied on `xcall` and should be asserted on `execute` and `reconcile`
 * @property to - The account that receives funds, in the event of a crosschain call,
 * will receive funds if the call fails.
 *
 * @param status - The transfer status [None, Reconciled, Executed, Completed]
 * @param nonce - The nonce on the origin domain used to ensure the transferIds are unique
 * @param originDomain - The originating domain (i.e. where `xcall` is called)
 * @param destinationDomain - The destination domain (i.e. where `execute` is called)\
 * @param reconcileDomain - The reconcile domain (i.e. where `reconcile` is called)\
 * @param canonicalDomain - The canonical domain of the asset you are bridging
 * @param canonicalId - The unique identifier of the canonical token corresponding to bridge assets
 * @param sender - The msg.sender of the xcall
 * @param receiver - The address you are sending funds (and potentially data) to
 * @param delegate - An address who can execute txs on behalf of `to`, in addition to allowing relayers
 * @param originAsset - The asset you are bridging
 * @param destinationAsset - The asset you are receiving on the destination domain
 * @param receiveLocal - If true, will use the local asset on the destination instead of adopted.
 * @param bridgedAmt - The amount sent over the bridge
 * @param callData - The data to execute on the receiving chain. If no crosschain call is needed, then leave empty.
 * @param strategy - The settlement strategy
 * @param strategyData - The data to execute the settlement strategy
 * @param routers - The routers who you are sending the funds on behalf of.
 * @param routerSignatures - Signatures belonging to the routers indicating permission to use funds
 * for the signed transfer ID.
 * @param sequencer - The sequencer who assigned the router path to this transfer.
 * @param sequencerSignature - Signature produced by the sequencer for path assignment accountability
 * for the path that was signed.
 */
struct TransferData {
  DestinationTransferStatus status;
  bytes32 transferId;
  uint256 nonce;
  uint32 originDomain;
  uint32 destinationDomain;
  uint32 reconcileDomain;
  uint32 canonicalDomain;
  bytes32 canonicalId;
  address sender;
  address receiver;
  address delegate;
  address originAsset;
  uint8 originAssetDecimals;
  address destinationAsset;
  uint8 destinationAssetDecimals;
  uint256 bridgedAmt;
  bytes callData;
  uint32 strategy;
  bytes strategyData;
  address[] routers;
  bytes[] routerSignatures;
  address sequencer;
  bytes sequencerSignature;
}

/**
 * @notice Contains configs for each router
 * @param approved Whether the router is allowlisted, settable by admin
 * @param routerOwners The address that can update the `recipient`
 * @param proposedRouterOwners Owner candidates
 * @param proposedRouterTimestamp When owner candidate was proposed (there is a delay to acceptance)
 */
struct RouterConfig {
  bool approved;
  address owner;
  address recipient;
  address proposed;
  uint256 proposedTimestamp;
}

/**
 * @notice Contains configurations for tokens
 * @dev Struct will be stored on the hash of the `canonicalId` and `canonicalDomain`. There are also
 * two separate reverse lookups, that deliver plaintext information based on the passed in address (can
 * either be representation or adopted address passed in).
 *
 * If the decimals are updated in a future token upgrade, the transfers should fail. If that happens, the
 * asset and swaps must be removed, and then they can be readded
 *
 * @param representation Address of minted asset on this domain. If the token is of local origin (meaning it was
 * originally deployed on this chain), this MUST map to address(0).
 * @param representationDecimals Decimals of minted asset on this domain
 * @param adopted Address of adopted asset on this domain
 * @param adoptedDecimals Decimals of adopted asset on this domain
 * @param approval Allowed assets
 */
struct TokenConfig {
  address representation;
  uint8 representationDecimals;
  address adopted;
  uint8 adoptedDecimals;
  bool approval;
}

struct AppStorage {
  //
  // 0
  bool initialized;
  //
  // Connext
  //
  // 1
  uint256 LIQUIDITY_FEE_NUMERATOR;
  /**
   * @notice The local address that is custodying relayer fees
   */
  // 2
  address relayerFeeVault;
  /**
   * @notice Nonce for the contract, used to keep unique transfer ids.
   * @dev Assigned at first interaction (xcall on origin domain).
   */
  // 3
  uint256 nonce;
  /**
   * @notice The domain this contract exists on.
   * @dev Must match the domain identifier, which is distinct from the "chainId".
   */
  // 4
  uint32 domain;
  /**
   * @notice Mapping of adopted to canonical asset information.
   */
  // 5
  mapping(address => TokenId) adoptedToCanonical;
  /**
   * @notice Mapping of representation to canonical asset information.
   */
  // 6
  mapping(address => TokenId) representationToCanonical;
  /**
   * @notice Mapping of hash(canonicalId, canonicalDomain) to token config on this domain.
   */
  // 7
  mapping(bytes32 => TokenConfig) tokenConfigs;
  /**
   * @notice Mapping to track transfer status on destination domain
   */
  // 8
  mapping(bytes32 => DestinationTransferStatus) transferStatus;
  /**
   * @notice Mapping to track transfer hashes on destination and reconcile domains
   */
  // 9
  mapping(uint64 => bytes32) transferHashes;
  /**
   * @notice Mapping holding router address that provided fast liquidity.
   */
  // 10
  mapping(bytes32 => address[]) routedTransfers;
  /**
   * @notice Mapping of router to available balance of an asset.
   * @dev Routers should always store liquidity that they can expect to receive via the bridge on
   * this domain (the local asset).
   */
  // 11
  mapping(address => mapping(address => uint256)) routerBalances;
  /**
   * @notice Mapping of approved relayers
   * @dev Send relayer fee if msg.sender is approvedRelayer; otherwise revert.
   */
  // 12
  mapping(address => bool) approvedRelayers;
  /**
   * @notice The max amount of routers a payment can be routed through.
   */
  // 13
  uint256 maxRoutersPerTransfer;
  /**
   * @notice Stores a mapping of remote routers keyed on domains.
   * @dev Addresses are cast to bytes32.
   * This mapping is required because the Connext now contains the BridgeRouter and must implement
   * the remotes interface.
   */
  // 14
  mapping(uint32 => bytes32) remotes;
  //
  // ProposedOwnable
  //
  // 16
  address _proposed;
  // 17
  uint256 _proposedOwnershipTimestamp;
  // 18
  bool _routerAllowlistRemoved;
  // 19
  uint256 _routerAllowlistTimestamp;
  /**
   * @notice Stores a mapping of address to Roles
   * @dev returns uint representing the enum Role value
   */
  // 20
  mapping(address => Role) roles;
  //
  // RouterFacet
  //
  // 21
  mapping(address => RouterConfig) routerConfigs;
  //
  // ReentrancyGuard
  //
  // 22
  uint256 _status;
  // 23
  uint256 _xcallStatus;
  /**
   * @notice Mapping of approved sequencers
   * @dev Sequencer address provided must belong to an approved sequencer in order to call `execute`
   * for the fast liquidity route.
   */
  // 24
  mapping(address => bool) approvedSequencers;
  /**
   * @notice Remote connection manager for xapp.
   */
  // 25
  IConnectorManager xAppConnectionManager;
}

library LibConnextStorage {
  function connextStorage() internal pure returns (AppStorage storage ds) {
    assembly {
      ds.slot := 0
    }
  }
}
