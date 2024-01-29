// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ConnextStorage} from "./ConnextStorage.sol";
import {Constants} from "../libraries/Constants.sol";

abstract contract BaseManager is ConnextStorage {

  // ============ Libraries ============
  
  using SafeERC20 for IERC20Metadata;

  // ========== Custom Errors ===========
  error BaseConnext__onlyOwner_notOwner();
  error BaseConnext__onlyOwnerOrRole_notOwnerOrRole(Role _role);
  error BaseConnext__whenNotPaused_paused();
  error BaseConnext__nonReentrant_reentrantCall();
  error BaseConnext__nonXCallReentrant_reentrantCall();
  error BaseConnext__delayElapsed_delayNotElapsed();
  error BaseConnext__handleIncomingAsset_nativeAssetNotSupported();
  error BaseConnext__handleIncomingAsset_feeOnTransferNotSupported();
  error BaseConnext__handleOutgoingAsset_notNative();
  error BaseConnext__getConfig_notRegistered();



  /**
   * @notice Returns the delay period before a new owner can be accepted.
   */
  function delay() public view returns (uint256) {
    return acceptanceDelay;
  }

  // ============ Modifiers ============

  /**
   * @dev Prevents a contract from calling itself, directly or indirectly.
   * Calling a `nonReentrant` function from another `nonReentrant`
   * function is not supported. It is possible to prevent this from happening
   * by making the `nonReentrant` function external, and making it call a
   * `private` function that does the actual work.
   */
  modifier nonReentrant() {
    // On the first call to nonReentrant, _notEntered will be true
    if (_status == Constants.ENTERED) revert BaseConnext__nonReentrant_reentrantCall();

    // Any calls to nonReentrant after this point will fail
    _status = Constants.ENTERED;

    _;

    // By storing the original value once again, a refund is triggered (see
    // https://eips.ethereum.org/EIPS/eip-2200)
    _status = Constants.NOT_ENTERED;
  }

  modifier nonXCallReentrant() {
    // On the first call to nonReentrant, _notEntered will be true
    if (_xcallStatus == Constants.ENTERED) revert BaseConnext__nonXCallReentrant_reentrantCall();

    // Any calls to nonReentrant after this point will fail
    _xcallStatus = Constants.ENTERED;

    _;

    // By storing the original value once again, a refund is triggered (see
    // https://eips.ethereum.org/EIPS/eip-2200)
    _xcallStatus = Constants.NOT_ENTERED;
  }

  /**
   * @notice Throws if called by any account other than the owner.
   */
  modifier onlyOwner() {
    if (owner != msg.sender) revert BaseConnext__onlyOwner_notOwner();
    _;
  }

  modifier onlyOwnerOrRole(Role _role) {
    if (owner != msg.sender && roles[msg.sender] != _role) {
      revert BaseConnext__onlyOwnerOrRole_notOwnerOrRole(_role);
    }
    _;
  }

  /**
   * @notice Throws if all functionality is paused
   */
  modifier whenNotPaused() {
    if (_paused) revert BaseConnext__whenNotPaused_paused();
    _;
  }

  // ============ Modifier ============
  /**
   * @notice Reverts the call if the expected delay has not elapsed.
   * @param start Timestamp marking the beginning of the delay period.
   */
  modifier delayElapsed(uint256 start) {
    // Ensure delay has elapsed
    if ((block.timestamp - start) <= delay()) revert BaseConnext__delayElapsed_delayNotElapsed();
    _;
  }

    /**
   * @notice Calculates the hash of canonical ID and domain.
   * @dev This hash is used as the key for many asset-related mappings.
   * @param _id Canonical ID.
   * @param _domain Canonical domain.
   * @return bytes32 Canonical hash, used as key for accessing token info from mappings.
   */
  function calculateCanonicalHash(bytes32 _id, uint32 _domain) internal pure returns (bytes32) {
    return keccak256(abi.encode(_id, _domain));
  }

      /**
   * @notice Handles transferring funds from msg.sender to the Connext contract.
   * @dev Does NOT work with fee-on-transfer tokens: will revert.
   *
   * @param _asset - The address of the ERC20 token to transfer.
   * @param _amount - The specified amount to transfer.
   */
  function _handleIncomingAsset(address _asset, uint256 _amount) internal {
    // Sanity check: if amount is 0, do nothing.
    if (_amount == 0) {
      return;
    }
    // Sanity check: asset address is not zero.
    if (_asset == address(0)) {
      revert  BaseConnext__handleIncomingAsset_nativeAssetNotSupported();
    }

    IERC20Metadata asset = IERC20Metadata(_asset);

    // Record starting amount to validate correct amount is transferred.
    uint256 starting = asset.balanceOf(address(this));

    // Transfer asset to contract.
    asset.safeTransferFrom(msg.sender, address(this), _amount);

    // Ensure correct amount was transferred (i.e. this was not a fee-on-transfer token).
    if (asset.balanceOf(address(this)) - starting != _amount) {
      revert  BaseConnext__handleIncomingAsset_feeOnTransferNotSupported();
    }
  }

    /**
   * @notice Handles transferring funds from the Connext contract to a specified address
   * @param _asset - The address of the ERC20 token to transfer.
   * @param _to - The recipient address that will receive the funds.
   * @param _amount - The amount to withdraw from contract.
   */
  function _handleOutgoingAsset(
    address _asset,
    address _to,
    uint256 _amount
  ) internal {
    // Sanity check: if amount is 0, do nothing.
    if (_amount == 0) {
      return;
    }
    // Sanity check: asset address is not zero.
    if (_asset == address(0)) revert BaseConnext__handleOutgoingAsset_notNative();

    // Transfer ERC20 asset to target recipient.
    SafeERC20.safeTransfer(IERC20Metadata(_asset), _to, _amount);
  }

  function _getConfig(bytes32 _key) internal view returns (TokenConfig storage) {
    TokenConfig storage config = tokenConfigs[_key];

    // Sanity check: not empty
    // NOTE: adopted decimals will *always* be nonzero (or reflect what is onchain
    // for the asset). The same is not true for the representation assets, which
    // will always have 0 decimals on the canonical domain
    if (config.adoptedDecimals < 1) {
      revert BaseConnext__getConfig_notRegistered();
    }

    return config;
  }
}
