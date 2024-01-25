// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Role, TokenId, TransferInfo} from "./LibConnextStorage.sol";
import {ConnextStorage} from "./ConnextStorage.sol";
import {Constants} from "../../connext/libraries/Constants.sol";

contract BaseConnext is ConnextStorage {
  // ========== Custom Errors ===========
  error BaseConnext__onlyOwner_notOwner();
  error BaseConnext__onlyOwnerOrRole_notOwnerOrRole(Role _role);
  error BaseConnext__whenNotPaused_paused();
  error BaseConnext__nonReentrant_reentrantCall();
  error BaseConnext__nonXCallReentrant_reentrantCall();
  error BaseConnext__delayElapsed_delayNotElapsed();

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
}
