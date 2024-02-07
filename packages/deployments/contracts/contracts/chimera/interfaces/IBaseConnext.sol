// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IBaseConnext {
  // ============= Enums =============

  /**
   * @notice Enum representing address role
   * @param None        - 0
   * @param RouterAdmin - 1
   * @param Watcher     - 2
   * @param Admin       - 3
   * @return uint8 - Index of value in enum
   */
  enum Role {
    None,
    RouterAdmin,
    Watcher,
    Admin
  }

  /**
   * @notice Enum representing status of destination transfer
   * @dev Status is only assigned on the destination domain, will always be `None` for the
   * origin domains
   * @param None       - 0
   * @param Reconciled - 1
   * @param Executed   - 2
   * @param Completed  - 3 - executed + reconciled
   * @return uint8 - Index of value in enum
   */
  enum DestinationTransferStatus {
    None,
    Reconciled,
    Executed,
    Completed
  }

  /**
   * @notice Enum representing types of `views` that we use in BridgeMessage. A view
   * points to a specific part of the memory and can slice bytes out of it. When we give a `type` to a view,
   * we define the structure of the data it points to, so that we can do easy runtime assertions without
   * having to fetch the whole data from memory and check for ourselves. In BridgeMessage.sol
   * the types of `data` we can have are defined in this enum and may belong to different taxonomies.
   * For example, a `Message` includes a `TokenId` and an Action (a `Transfer`).
   * The Message is a different TYPE of data than a TokenId or Transfer, as TokenId and Transfer live inside
   * the message. For that reason, we define them as different data types and we add them to the same enum
   * for ease of use.
   * @dev WARNING: do NOT re-write the numbers / order
   * of message types in an upgrade;
   * will cause in-flight messages to be mis-interpreted
   * @param Invalid  - 0
   * @param TokenId  - 1
   * @param Message  - 2
   * @param Transfer - 3
   * @return uint8 - Index of value in enum
   */
  enum Types {
    Invalid,
    TokenId,
    Message,
    Transfer
  }

  // ============= Structs =============

  /**
   * @notice These are the parameters that will remain constant between the
   * two chains. They are supplied on `xcall` and should be asserted on `execute`
   * @dev The account that receives funds, in the event of a crosschain call,
   * will receive funds if the call fails.
   *
   * @param originDomain - The originating domain (i.e. where `xcall` is called)
   * @param destinationDomain - The final domain (i.e. where `execute` / `reconcile` are called)\
   * @param canonicalDomain - The canonical domain of the asset you are bridging
   * @param to - The address you are sending funds (and potentially data) to
   * @param delegate - An address who can execute txs on behalf of `to`, in addition to allowing relayers
   * @param receiveLocal - If true, will use the local asset on the destination instead of adopted.
   * @param callData - The data to execute on the receiving chain. If no crosschain call is needed, then leave empty.
   * @param slippage - Slippage user is willing to accept from original amount in expressed in BPS (i.e. if
   * a user takes 1% slippage, this is expressed as 1_000)
   * @param originSender - The msg.sender of the xcall
   * @param bridgedAmt - The amount sent over the bridge (after potential AMM on xcall)
   * @param normalizedIn - The amount sent to `xcall`, normalized to 18 decimals
   * @param nonce - The nonce on the origin domain used to ensure the transferIds are unique
   * @param canonicalId - The unique identifier of the canonical token corresponding to bridge assets
   */
  struct TransferInfo {
    uint32 originDomain;
    uint32 destinationDomain;
    uint32 canonicalDomain;
    address to;
    address delegate;
    bool receiveLocal;
    bytes callData;
    uint256 slippage;
    address originSender;
    uint256 bridgedAmt;
    uint256 normalizedIn;
    uint256 nonce;
    bytes32 canonicalId;
  }

  /**
   * @notice These are the parameters supplied on `execute`
   * @param params - The TransferInfo. These are consistent across sending and receiving chains.
   * @param routers - The routers who you are sending the funds on behalf of.
   * @param routerSignatures - Signatures belonging to the routers indicating permission to use funds
   * for the signed transfer ID.
   * @param sequencer - The sequencer who assigned the router path to this transfer.
   * @param sequencerSignature - Signature produced by the sequencer for path assignment accountability
   * for the path that was signed.
   */
  struct ExecuteArgs {
    TransferInfo params;
    address[] routers;
    bytes[] routerSignatures;
    address sequencer;
    bytes sequencerSignature;
  }

  /**
   * @notice Contains configs for each router
   * @param approved - Whether the router is allowlisted, settable by admin
   * @param portalApproved - Whether the router is allowlisted for portals, settable by admin
   * @param routerOwners - The address that can update the `recipient`
   * @param proposedRouterOwners - Owner candidates
   * @param proposedRouterTimestamp - When owner candidate was proposed (there is a delay to acceptance)
   */
  struct RouterConfig {
    bool approved;
    bool portalApproved; // TODO: remove
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
   * @param representation - Address of minted asset on this domain. If the token is of local origin (meaning it was
   * originally deployed on this chain), this MUST map to address(0).
   * @param representationDecimals - Decimals of minted asset on this domain
   * @param adopted - Address of adopted asset on this domain
   * @param adoptedDecimals - Decimals of adopted asset on this domain
   * @param adoptedToLocalExternalPools - Holds the AMMs for swapping in and out of local assets
   * @param approval - Allowed assets
   * @param cap - Liquidity caps of whitelisted assets. If 0, no cap is enforced.
   * @param custodied - Custodied balance by address
   */
  struct TokenConfig {
    address representation;
    uint8 representationDecimals;
    address adopted;
    uint8 adoptedDecimals;
    address adoptedToLocalExternalPools; // TODO: remove
    bool approval;
    uint256 cap;
    uint256 custodied;
  }

  /**
   * @notice Tokens are identified by a TokenId:
   * @param domain - 4 byte chain ID of the chain from which the token originates
   * @param id - 32 byte identifier of the token address on the origin chain, in that chain's address format
   */
  struct TokenId {
    uint32 domain;
    bytes32 id;
  }

  /**
   * @notice Defines the fields needed for an asset transfer
   * @param asset - The address of the asset
   * @param amount - The amount of the asset
   */
  struct AssetTransfer {
    address asset;
    uint256 amount;
  }
}
