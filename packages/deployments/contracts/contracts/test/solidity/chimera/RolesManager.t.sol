// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {TestExtended} from '../utils/TestExtended.sol';

import {IRolesManager, RolesManager} from '@contracts/chimera/managers/RolesManager.sol';
import {BaseManager} from '@contracts/chimera/managers/BaseManager.sol';
import {IBaseConnext} from '@contracts/chimera/interfaces/IBaseConnext.sol';
import {TypeCasts} from '@contracts/shared/libraries/TypeCasts.sol';

contract RolesManagerForTest is RolesManager {
  function test_setRouterAllowlistRemoved(bool _removed) public {
    routerAllowlistRemoved = _removed;
  }
}

abstract contract Base is TestExtended {
  RolesManager public rolesManager;
  address public owner = makeAddr('owner');

  function setUp() public virtual {
    vm.prank(owner);
    rolesManager = new RolesManagerForTest();
  }

  function _setRole(address _account, IBaseConnext.Role _role) internal {
    vm.prank(owner);

    rolesManager.assignRole(_account, _role);
  }

  function _validRole(uint8 _role) internal pure {
    vm.assume(_role > uint8(IBaseConnext.Role.None) && _role <= uint8(IBaseConnext.Role.Admin));
  }

  function _validAccount(address _account) internal pure {
    vm.assume(_account != address(0));
  }

  modifier setAccountRoleNotAdminOrOwner(address _unauthorized, uint8 _role) {
    vm.assume(_unauthorized != owner && _unauthorized != address(0));
    vm.assume(_role < uint8(IBaseConnext.Role.Admin));
    _setRole(_unauthorized, IBaseConnext.Role(_role));
    _;
  }

  modifier setAdmin(address _account) {
    vm.assume(_account != owner);
    _validAccount(_account);
    _setRole(_account, IBaseConnext.Role.Admin);
    _;
  }

  modifier validRole(uint8 _role) {
    _validRole(_role);
    _;
  }

  modifier validRoleAndAccount(uint8 _role, address _account) {
    _validRole(_role);
    _validAccount(_account);
    _;
  }

  modifier validAccount(address _account) {
    _validAccount(_account);
    _;
  }

  modifier setRole(address _account, uint8 _role) {
    _validAccount(_account);
    _validRole(_role);
    _setRole(_account, IBaseConnext.Role(_role));
    _;
  }
}

contract Unit_ProposeRouterAllowlistRemoval is Base {
  event RouterAllowlistRemovalProposed(uint256 _timestamp);

  function test_Set_RouterAllowlistTimestamp(uint48 _timestamp) public {
    vm.warp(_timestamp);
    vm.prank(owner);

    rolesManager.proposeRouterAllowlistRemoval();
    assertEq(rolesManager.routerAllowlistTimestamp(), _timestamp);
  }

  function test_Emit_RouterAllowlistRemovalProposed(uint48 _timestamp) public {
    vm.warp(_timestamp);
    vm.prank(owner);

    _expectEmit(address(rolesManager));
    emit RouterAllowlistRemovalProposed(_timestamp);

    rolesManager.proposeRouterAllowlistRemoval();
  }

  function test_Admin_Proposes_RouterAllowlistRemoval(address _admin) public setAdmin(_admin) {
    vm.prank(_admin);

    _expectEmit(address(rolesManager));
    emit RouterAllowlistRemovalProposed(block.timestamp);

    rolesManager.proposeRouterAllowlistRemoval();
  }

  function test_Revert_OnlyOwnerOrAdmin(
    address _unauthorized,
    uint8 _role
  ) public setAccountRoleNotAdminOrOwner(_unauthorized, _role) {
    vm.expectRevert(
      abi.encodeWithSelector(BaseManager.BaseManager__onlyOwnerOrRole_notOwnerOrRole.selector, IBaseConnext.Role.Admin)
    );

    vm.prank(_unauthorized);
    rolesManager.proposeRouterAllowlistRemoval();
  }

  function test_Revert_RouterAllowlistRemoved() public {
    RolesManagerForTest(address(rolesManager)).test_setRouterAllowlistRemoved(true);

    vm.expectRevert(IRolesManager.RolesManager__proposeRouterAllowlistRemoval_noOwnershipChange.selector);

    vm.prank(owner);
    rolesManager.proposeRouterAllowlistRemoval();
  }
}

contract Unit_RemoveRouterAllowlist is Base {
  event RouterAllowlistRemoved(bool _renounced);

  function _proposeRouterAllowlistRemoval() internal {
    vm.prank(owner);
    rolesManager.proposeRouterAllowlistRemoval();
  }

  function _elapseDelay() internal {
    vm.warp(block.timestamp + rolesManager.acceptanceDelay() + 1);
  }

  modifier proposeRouterAllowlistRemovalAndElapseDelay() {
    _proposeRouterAllowlistRemoval();
    _elapseDelay();
    _;
  }

  function test_Set_RouterAllowlistRemoved() public proposeRouterAllowlistRemovalAndElapseDelay {
    vm.prank(owner);
    rolesManager.removeRouterAllowlist();

    assertTrue(rolesManager.routerAllowlistRemoved());
  }

  function test_Set_RouterAllowlistTimestamp() public proposeRouterAllowlistRemovalAndElapseDelay {
    vm.prank(owner);
    rolesManager.removeRouterAllowlist();

    assertEq(rolesManager.routerAllowlistTimestamp(), 0);
  }

  function test_Emit_RouterAllowlistRemoved() public proposeRouterAllowlistRemovalAndElapseDelay {
    _expectEmit(address(rolesManager));
    emit RouterAllowlistRemoved(true);

    vm.prank(owner);
    rolesManager.removeRouterAllowlist();
  }

  function test_Admin_RemovesRouterAllowList(address _admin)
    public
    setAdmin(_admin)
    proposeRouterAllowlistRemovalAndElapseDelay
  {
    vm.prank(_admin);

    _expectEmit(address(rolesManager));
    emit RouterAllowlistRemoved(true);

    rolesManager.removeRouterAllowlist();
  }

  function test_Revert_OnlyOwnerOrAdmin(
    address _unauthorized,
    uint8 _role
  ) public proposeRouterAllowlistRemovalAndElapseDelay setAccountRoleNotAdminOrOwner(_unauthorized, _role) {
    vm.expectRevert(
      abi.encodeWithSelector(BaseManager.BaseManager__onlyOwnerOrRole_notOwnerOrRole.selector, IBaseConnext.Role.Admin)
    );

    vm.prank(_unauthorized);
    rolesManager.removeRouterAllowlist();
  }

  function test_Revert_RouterAllowlistRemoved() public {
    RolesManagerForTest(address(rolesManager)).test_setRouterAllowlistRemoved(true);

    vm.expectRevert(IRolesManager.RolesManager__removeRouterAllowlist_noOwnershipChange.selector);

    vm.prank(owner);
    rolesManager.removeRouterAllowlist();
  }

  function test_Revert_NoProposal() public {
    vm.expectRevert(IRolesManager.RolesManager__removeRouterAllowlist_noProposal.selector);

    vm.prank(owner);
    rolesManager.removeRouterAllowlist();
  }
}

contract Unit_AssignRole is Base {
  event AssignRole(address _account, IBaseConnext.Role _role);

  function test_Set_Role(address _account, uint8 _role) public validRoleAndAccount(_role, _account) {
    _setRole(_account, IBaseConnext.Role(_role));

    assertEq(uint8(rolesManager.roles(_account)), _role);
  }

  function test_Emit_AssignRole(address _account, uint8 _role) public validRoleAndAccount(_role, _account) {
    _expectEmit(address(rolesManager));
    emit AssignRole(_account, IBaseConnext.Role(_role));

    _setRole(_account, IBaseConnext.Role(_role));
  }

  function test_Admin_AssignsRole(
    address _admin,
    address _account,
    uint8 _role
  ) public validRoleAndAccount(_role, _account) setAdmin(_admin) {
    vm.assume(_role < uint8(IBaseConnext.Role.Admin));

    _expectEmit(address(rolesManager));
    emit AssignRole(_account, IBaseConnext.Role(_role));

    vm.prank(_admin);
    rolesManager.assignRole(_account, IBaseConnext.Role(_role));
  }

  function test_Revert_OnlyOwnerOrAdmin(
    address _unauthorized,
    uint8 _role
  ) public setAccountRoleNotAdminOrOwner(_unauthorized, _role) {
    vm.expectRevert(
      abi.encodeWithSelector(BaseManager.BaseManager__onlyOwnerOrRole_notOwnerOrRole.selector, IBaseConnext.Role.Admin)
    );

    vm.prank(_unauthorized);
    rolesManager.assignRole(_unauthorized, IBaseConnext.Role(_role));
  }

  function test_Revert_InvalidInputRoleAlreadyAssigned(
    address _account,
    uint8 _role,
    uint8 _newRole
  ) public validRole(_role) validRole(_newRole) validAccount(_account) {
    _setRole(_account, IBaseConnext.Role(_role));

    vm.expectRevert(
      abi.encodeWithSelector(
        IRolesManager.RolesManager__assignRole_invalidInput.selector,
        _account,
        IBaseConnext.Role(_role),
        IBaseConnext.Role(_newRole)
      )
    );

    _setRole(_account, IBaseConnext.Role(_newRole));
  }

  function test_Revert_InvalidInputZeroAddress(uint8 _role) public validRole(_role) {
    vm.expectRevert(
      abi.encodeWithSelector(
        IRolesManager.RolesManager__assignRole_invalidInput.selector,
        address(0),
        IBaseConnext.Role(IBaseConnext.Role.None),
        IBaseConnext.Role(_role)
      )
    );

    _setRole(address(0), IBaseConnext.Role(_role));
  }

  function test_Revert_OnlyOwnerCanAssignAdmin(address _admin, address _account) public setAdmin(_admin) {
    vm.expectRevert(IRolesManager.RolesManager__assignRole_onlyOwnerCanAssignAdmin.selector);

    vm.prank(_admin);
    rolesManager.assignRole(_account, IBaseConnext.Role.Admin);
  }
}

contract Unit_RevokeRole is Base {
  event RevokeRole(address _revokedAddress, IBaseConnext.Role _revokedRole);

  function _revokeRole(address _account) internal {
    vm.prank(owner);
    rolesManager.revokeRole(_account);
  }

  function test_Set_RoleNone(address _account, uint8 _role) public setRole(_account, _role) {
    _revokeRole(_account);

    assertEq(uint8(rolesManager.roles(_account)), uint8(IBaseConnext.Role.None));
  }

  function test_Emit_RevokeRole(address _account, uint8 _role) public setRole(_account, _role) {
    _expectEmit(address(rolesManager));
    emit RevokeRole(_account, IBaseConnext.Role(_role));

    _revokeRole(_account);
  }

  function test_Admin_RevokesRole(
    address _admin,
    address _account,
    uint8 _role
  ) public validRoleAndAccount(_role, _account) setAdmin(_admin) {
    vm.assume(_role < uint8(IBaseConnext.Role.Admin));

    _setRole(_account, IBaseConnext.Role(_role));

    _expectEmit(address(rolesManager));
    emit RevokeRole(_account, IBaseConnext.Role(_role));

    vm.prank(_admin);
    rolesManager.revokeRole(_account);
  }

  function test_Revert_OnlyOwnerOrAdmin(
    address _unauthorized,
    uint8 _role
  ) public setAccountRoleNotAdminOrOwner(_unauthorized, _role) {
    vm.expectRevert(
      abi.encodeWithSelector(BaseManager.BaseManager__onlyOwnerOrRole_notOwnerOrRole.selector, IBaseConnext.Role.Admin)
    );

    vm.prank(_unauthorized);
    rolesManager.revokeRole(_unauthorized);
  }

  function test_Revert_InvalidInputRoleNotAssigned(address _account) public validAccount(_account) {
    vm.expectRevert(IRolesManager.RolesManager__revokeRole_invalidInput.selector);

    _revokeRole(_account);
  }

  function test_Revert_InvalidInputZeroAddress(uint8 _role) public validRole(_role) {
    vm.expectRevert(IRolesManager.RolesManager__revokeRole_invalidInput.selector);

    _revokeRole(address(0));
  }

  function test_Revert_OnlyOwnerCanRevokeAdmin(
    address _admin,
    address _account
  ) public setAdmin(_admin) setAdmin(_account) {
    vm.expectRevert(IRolesManager.RolesManager__assignRole_onlyOwnerCanRevokeAdmin.selector);

    vm.prank(_admin);
    rolesManager.revokeRole(_account);
  }
}

contract Unit_EnrollRemoteRouter is Base {
  event RemoteAdded(uint32 _domain, address _remote, address _caller);

  modifier validDomain(uint32 _domain) {
    vm.assume(_domain > 0 && _domain != rolesManager.domain());
    _;
  }

  modifier validRouter(bytes32 _router) {
    vm.assume(_router != bytes32(''));
    _;
  }

  function test_Set_Remote(uint32 _domain, bytes32 _router) public validDomain(_domain) validRouter(_router) {
    vm.prank(owner);
    rolesManager.enrollRemoteRouter(_domain, _router);

    assertEq(rolesManager.remotes(_domain), _router);
  }

  function test_Emit_RemoteAdded(uint32 _domain, bytes32 _router) public validDomain(_domain) validRouter(_router) {
    _expectEmit(address(rolesManager));
    emit RemoteAdded(_domain, TypeCasts.bytes32ToAddress(_router), address(owner));

    vm.prank(owner);
    rolesManager.enrollRemoteRouter(_domain, _router);
  }

  function test_Admin_AddsRemote(
    uint32 _domain,
    bytes32 _router,
    address _admin
  ) public validDomain(_domain) validRouter(_router) setAdmin(_admin) {
    _expectEmit(address(rolesManager));
    emit RemoteAdded(_domain, TypeCasts.bytes32ToAddress(_router), address(_admin));

    vm.prank(_admin);
    rolesManager.enrollRemoteRouter(_domain, _router);
  }

  function test_Revert_InvalidRouter(uint32 _domain) public validDomain(_domain) {
    vm.expectRevert(IRolesManager.RolesManager__addRemote_invalidRouter.selector);

    vm.prank(owner);
    rolesManager.enrollRemoteRouter(_domain, bytes32(''));
  }

  function test_Revert_InvalidDomain_SameDomain(bytes32 _router) public validRouter(_router) {
    uint32 _domain = rolesManager.domain();
    vm.expectRevert(IRolesManager.RolesManager__addRemote_invalidDomain.selector);

    vm.prank(owner);
    rolesManager.enrollRemoteRouter(_domain, _router);
  }
}
