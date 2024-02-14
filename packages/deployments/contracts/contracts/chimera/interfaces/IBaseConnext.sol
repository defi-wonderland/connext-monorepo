// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.17;

interface IBaseConnext {
  // ============= Enums =============

  /**
   * @notice Enum representing address role
   * @param None         - 0
   * @param Router       - 1
   * @param Relayer      - 2
   * @param Watcher      - 3
   * @param Sequencer    - 4
   * @param AssetManager - 5
   * @param Admin        - 6
   * @return uint8 - Index of value in enum
   */
  enum Role {
    None,
    Router,
    Relayer,
    Watcher,
    Sequencer,
    AssetManager,
    Admin
  }

  /**
   * @notice Enum representing status of transfer
   * @dev Status is only assigned on the destination and reconciliation domains, will always be `None` for the
   * origin domains
   * @param None       - 0
   * @param Reconciled - 1
   * @param Executed   - 2
   * @param Completed  - 3 - executed + reconciled
   * @return uint8 - Index of value in enum
   */
  enum TransferStatus {
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
   * @param Execute  - 4
   * @param Credit   - 5
   * @return uint8 - Index of value in enum
   */
  enum MessageType {
    Invalid,
    TokenId,
    Message,
    Transfer,
    Execute,
    Credit
  }

  // ============= Structs =============

  /**
   * @notice These are the parameters that will remain constant between the
   * two chains. They are supplied on `xcall` and should be asserted on `execute`
   * @dev The account that receives funds, in the event of a crosschain call,
   * will receive funds if the call fails.
   *
   * @param originDomain - The originating domain (i.e. where `xcall` is called)
   * @param destinationDomain - The receiving domain (i.e. where `execute` is called)
   * @param canonicalDomain - The canonical domain of the asset you are bridging
   * @param to - The address you are sending funds (and potentially data) to
   * @param callData - The data to execute on the receiving chain. If no crosschain call is needed, then leave empty.
   * @param originSender - The msg.sender of the xcall
   * @param bridgedAmt - The amount sent over the bridge
   * @param normalizedIn - The amount sent to `xcall`, normalized to 18 decimals
   * @param nonce - The nonce on the origin domain used to ensure the transferIds are unique
   * @param canonicalId - The unique identifier of the canonical token corresponding to bridge assets
   */
  struct TransferInfo {
    uint32 originDomain;
    uint32 destinationDomain;
    uint32 canonicalDomain;
    address to;
    bytes callData;
    address originSender;
    uint256 bridgedAmt;
    uint256 normalizedIn;
    uint256 nonce;
    bytes32 canonicalId;
  }

  /**
   * @notice These are the parameters supplied on `execute`
   * @param params - The TransferInfo. These are consistent across sending and receiving chains.
   * @param reconciliationDomain - The reconciling domain (i.e. where `reconcile` is called)
   * @param routers - The routers who you are sending the funds on behalf of.
   * @param routerSignatures - Signatures belonging to the routers indicating permission to use funds
   * for the signed transfer ID.
   * @param sequencer - The sequencer who assigned the router path to this transfer.
   * @param sequencerSignature - Signature produced by the sequencer for path assignment accountability
   * for the path that was signed.
   */
  struct ExecuteArgs {
    TransferInfo params;
    uint32 reconciliationDomain;
    address[] routers;
    bytes[] routerSignatures;
    address sequencer;
    bytes sequencerSignature;
  }

  /**
   * @notice Contains configs for each router
   * @param approved - Whether the router is allowlisted, settable by admin
   * @param routerOwners - The address that can update the `recipient`
   * @param proposedRouterOwners - Owner candidates
   * @param proposedRouterTimestamp - When owner candidate was proposed (there is a delay to acceptance)
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
   * @dev Struct will be stored on the hash of the `canonicalId` and `canonicalDomain`. There is also
   * a separate reverse lookup, that delivers plaintext information based on the passed in asset address.
   *
   * If the decimals are updated in a future token upgrade, the transfers should fail. If that happens, the
   * asset must be removed, and then they can be readded
   *
   * @param asset - Address of asset on this domain
   * @param assetDecimals - Decimals of asset on this domain
   * @param approval - Allowed assets
   */
  struct TokenConfig {
    address asset;
    uint8 assetDecimals;
    bool approval;
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
   * @notice Contains configurations for fees
   * @dev Struct will be stored on the hash of the `canonicalId` and `canonicalDomain`.
   *
   * @param routingFee - The routing fee
   * @param protocolFee - The protocol fee
   * @param externalFee - The external fee
   * @param externalFeeAddress - The address of the external fee recipient
   */
  struct FeeConfig {
    uint256 routingFee;
    uint256 protocolFee;
    uint256 externalFee;
    address externalFeeAddress;
  }
}
