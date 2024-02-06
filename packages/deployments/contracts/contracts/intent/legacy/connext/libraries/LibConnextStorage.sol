// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import {IStableSwap} from "../interfaces/IStableSwap.sol";
import {IConnectorManager} from "../../../messaging/interfaces/IConnectorManager.sol";
import {SwapUtils} from "./SwapUtils.sol";
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
 * two chains. They are supplied on `xcall` and should be asserted on `execute`
 * @property to - The account that receives funds, in the event of a crosschain call,
 * will receive funds if the call fails.
 *
 * @param originDomain - The originating domain (i.e. where `xcall` is called)
 * @param destinationDomain - The final domain (i.e. where `execute` / `reconcile` are called)\
 * @param canonicalDomain - The canonical domain of the asset you are bridging
 * @param to - The address you are sending funds (and potentially data) to
 * @param callData - The data to execute on the receiving chain. If no crosschain call is needed, then leave empty.
 * @param originSender - The msg.sender of the xcall
 * @param amount - The amount sent over the bridge
 * @param normalizedIn - The amount sent to `xcall`, normalized to 18 decimals
 * @param nonce - The nonce on the origin domain used to ensure the transferIds are unique
 * @param canonicalId - The unique identifier of the canonical token corresponding to bridge assets
 */
struct TransferInfo {
  uint32 originDomain;
  uint32 destinationDomain;
  address to;
  bytes callData;
  address originSender;
  uint256 amount;
  uint256 nonce;
  bytes32 canonicalId;
}

/**
 * @notice
 * @param params - The TransferInfo. These are consistent across sending and receiving chains.
 * @param routers - The routers who you are sending the funds on behalf of.
 * @param routerSignatures - Signatures belonging to the routers indicating permission to use funds
 * for the signed transfer ID.
 * @param sequencer - The sequencer who assigned the router path to this transfer.
 * @param sequencerSignature - Signature produced by the sequencer for path assignment accountability
 * for the path that was signed.
 * @param settlementDomain - The domain router will reconcile their transaction on.
 */
struct ExecuteArgs {
  TransferInfo params;
  address[] routers;
  bytes[] routerSignatures;
  address sequencer;
  bytes sequencerSignature;
  uint32 settlementDomain;
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
 * @param tokenAddress Address of asset on this domain
 * @param decimals Decimals of adopted asset on this domain
 * @param approval Allowed assets
 * @param settlementStrategy Mechanism used to settle transfers of this asset across domains
 */
struct TokenConfig {
  address tokenAddress;
  uint8 decimals;
  bool approval; // TODO what is this? Description unhelpful.
  SettlementStrategy settlementStrategy; // TODO How should this be structured?.
  FeeConfig feeConfig;
}

/**
 * @notice Defines the settlement strategy for a given token
 * @dev We specifically define which domains are supported for the strategy, as not all tokens will have
 * just a single strategy that works on all chains (e.g. CCTP). If a token is attempted to be transfered from origin ->
 * destination but one or neither of the domains is supported by the strategy, then the system to fall back
 * to the default Multilateral settlement strategy.
 *
 * @param supportedDomains[] Array of all domains supported as part of the settlement strategy
 * @param settlementId Unique identifier of settlement strategy
 */
struct SettlementStrategy {
  uint32[] supportedDomains; // TODO should this be an array? Need something cheap/easy to search through.
  address settlementId; // TODO Should this be address? Need some identifier that is easily extensible.
}

/**
 * @notice Defines the fee structure for a given token
 * @dev should be checked as part of execute. Protocol admins and specified external actors should be able to call
 * a sweep fees function (TODO implement)
 * @dev all fees are specified as BPS
 *
 * @param routerFeeRate Fee rate of routers (current: 5bps)
 * @param protocolFeeRate Fee rate of protocol
 * @param externalFeeRate Fee rate of external actors, e.g. token issuers. (default: 0bps)
 * @param externalSweepAddress Address capable of sweeping external actor fees
 */

struct FeeConfig {
  uint8 routerFeeRate;
  uint8 protocolFeeRate;
  // TODO do we need a sweep address for protocol?
  uint8 externalFeeRate;
  address externalSweepAddress;
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
   * @notice Mapping of address to canonical asset information.
   */
  // 5
  mapping(address => TokenId) addressToCanonical;
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
   * @notice Mapping holding router address that provided fast liquidity.
   */
  // 9
  mapping(bytes32 => address[]) routedTransfers;
  /**
   * @notice Mapping of router to available balance of an asset.
   * @dev Routers should always store liquidity that they can expect to receive via the bridge on
   * this domain (the local asset).
   */
  // 10
  mapping(address => mapping(address => uint256)) routerBalances;
  /**
   * @notice Mapping of approved relayers
   * @dev Send relayer fee if msg.sender is approvedRelayer; otherwise revert.
   */
  // 11
  mapping(address => bool) approvedRelayers;
  /**
   * @notice The max amount of routers a payment can be routed through.
   */
  // 12
  uint256 maxRoutersPerTransfer;
  // TODO Arjun: I deleted a bunch of stuff here, but only to play around. Missing data structures MUST be readded.

  /**
   * @notice Stores a mapping of remote routers keyed on domains.
   * @dev Addresses are cast to bytes32.
   * This mapping is required because the Connext now contains the BridgeRouter and must implement
   * the remotes interface.
   */
  // 15
  mapping(uint32 => bytes32) remotes;
  //
  // ProposedOwnable
  //
  // 17
  address _proposed;
  // 18
  uint256 _proposedOwnershipTimestamp;
  // 19
  bool _routerAllowlistRemoved;
  // 20
  uint256 _routerAllowlistTimestamp;
  /**
   * @notice Stores a mapping of address to Roles
   * @dev returns uint representing the enum Role value
   */
  // 21
  mapping(address => Role) roles;
  //
  // RouterFacet
  //
  // 22
  mapping(address => RouterConfig) routerConfigs;
  //
  // ReentrancyGuard
  //
  // 23
  uint256 _status;
  // 24
  uint256 _xcallStatus;
  //

  /**
   * @notice Mapping of approved sequencers
   * @dev Sequencer address provided must belong to an approved sequencer in order to call `execute`
   * for the fast liquidity route.
   */
  // 33
  mapping(address => bool) approvedSequencers;
  /**
   * @notice Remote connection manager for xapp.
   */
  // 34
  IConnectorManager xAppConnectionManager;
}

library LibConnextStorage {
  function connextStorage() internal pure returns (AppStorage storage ds) {
    assembly {
      ds.slot := 0
    }
  }
}
