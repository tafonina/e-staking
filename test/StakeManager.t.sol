// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import "../src/StakeManager.sol";
import "../src/interfaces/IStakeManagerEvents.sol";

contract StakeManagerTest is Test, IStakeManagerEvents {
    uint256 public constant DEFAULT_REGISTRATION_DEPOSIT_AMOUNT = 100;
    uint256 public constant DEFAULT_STAKE_DEPOSIT_AMOUNT = 50;
    uint256 public constant DEFAULT_WITHDRAWAL_WAIT_TIME = 100;
    uint256 public constant INITIAL_STAKER_WALLET_BALANCE = 1 ether;
    bytes32 public constant STAKER_ROLE1 = keccak256("STAKER_ROLE1");
    bytes32 public constant STAKER_ROLE2 = keccak256("STAKER_ROLE2");
    bytes32 public constant STAKER_ROLE3 = keccak256("STAKER_ROLE3");
    bytes32 public constant NONEXISTENT_STAKER_ROLE = keccak256("STAKER_ROLE4");

    address private _staker1 = vm.addr(1);
    address private _staker2 = vm.addr(2);
    address private _staker3 = vm.addr(3);
    bytes32[] private _stakerRolesIds;
    bytes32[] private _additionalStakerRolesIds;
    bytes32[] private _badStakerRolesIds;

    StakeManager public stakeManager;

    function setUp() public {
        _stakerRolesIds.push(STAKER_ROLE1);
        _stakerRolesIds.push(STAKER_ROLE2);
        _additionalStakerRolesIds.push(STAKER_ROLE3);
        _badStakerRolesIds.push(NONEXISTENT_STAKER_ROLE);

        stakeManager = new StakeManager();
        stakeManager.initialize(DEFAULT_REGISTRATION_DEPOSIT_AMOUNT, DEFAULT_WITHDRAWAL_WAIT_TIME);
        vm.deal(_staker1, INITIAL_STAKER_WALLET_BALANCE);
        vm.deal(_staker2, INITIAL_STAKER_WALLET_BALANCE);
    }

    function test_Initialize() public {
        assertEq(stakeManager.getRegistrationDepositAmount(), DEFAULT_REGISTRATION_DEPOSIT_AMOUNT);
        assertEq(stakeManager.getWithdrawalWaitTime(), DEFAULT_WITHDRAWAL_WAIT_TIME);
        assert(stakeManager.hasRole(stakeManager.DEFAULT_ADMIN_ROLE(), address(this)));
        // check admin is not registered as staker
        assert(!stakeManager.isStakerRegistered(address(this)));

        assertEq(stakeManager.getStakedBalance(address(this)), 0);
        assertEq(address(stakeManager).balance, 0);
    }

    function test_SetConfiguration() public {
        stakeManager.setConfiguration(DEFAULT_REGISTRATION_DEPOSIT_AMOUNT + 1, DEFAULT_WITHDRAWAL_WAIT_TIME + 1);
        assertEq(stakeManager.getRegistrationDepositAmount(), DEFAULT_REGISTRATION_DEPOSIT_AMOUNT + 1);
        assertEq(stakeManager.getWithdrawalWaitTime(), DEFAULT_WITHDRAWAL_WAIT_TIME + 1);
    }

    function testFuzz_SetConfiguration_AllowZeroValue() public {
        stakeManager.setConfiguration(0, 0);
        assertEq(stakeManager.getRegistrationDepositAmount(), 0);
        assertEq(stakeManager.getWithdrawalWaitTime(), 0);
    }

    function test_SetConfigurationRevertIf_NotAdmin() public {
        vm.prank(_staker1);
        vm.expectRevert(AdminRoleNotGranted.selector);
        stakeManager.setConfiguration(DEFAULT_REGISTRATION_DEPOSIT_AMOUNT + 1, DEFAULT_WITHDRAWAL_WAIT_TIME + 1);
    }

    function testFuzz_SetConfiguration(uint256 x, uint256 y) public {
        stakeManager.setConfiguration(x, y);
        assertEq(stakeManager.getRegistrationDepositAmount(), x);
        assertEq(stakeManager.getWithdrawalWaitTime(), y);
    }

    function test_Register() public {
        vm.prank(_staker1);
        vm.expectEmit();
        emit Registered(_staker1, _stakerRolesIds);
        stakeManager.register{value: DEFAULT_REGISTRATION_DEPOSIT_AMOUNT}(_stakerRolesIds);
        assert(stakeManager.isStakerRegistered(_staker1));
        assert(stakeManager.hasRole(_stakerRolesIds[0], _staker1));
        assert(stakeManager.hasRole(_stakerRolesIds[1], _staker1));
        assertEq(address(stakeManager).balance, DEFAULT_REGISTRATION_DEPOSIT_AMOUNT);
        assertEq(stakeManager.getStakedBalance(_staker1), DEFAULT_REGISTRATION_DEPOSIT_AMOUNT);
        assertEq(address(_staker1).balance, INITIAL_STAKER_WALLET_BALANCE - DEFAULT_REGISTRATION_DEPOSIT_AMOUNT);
    }

    function test_RegisterRevertIf_NotEnoughAmount() public {
        vm.prank(_staker1);
        vm.expectRevert(NotEnoughDepositAmount.selector);
        stakeManager.register{value: DEFAULT_REGISTRATION_DEPOSIT_AMOUNT - 1}(_stakerRolesIds);
    }

    function test_RegisterRevertIf_RoleDoesntExist() public {
        vm.prank(_staker1);
        vm.expectRevert(RoleDoesntExist.selector);
        stakeManager.register{value: DEFAULT_REGISTRATION_DEPOSIT_AMOUNT}(_badStakerRolesIds);
    }

    function test_RegisterRevertIf_AlreadyRegisteredRole() public {
        test_Register();
        vm.prank(_staker1);
        vm.expectRevert(AlreadyRegisteredRole.selector);
        stakeManager.register{value: DEFAULT_REGISTRATION_DEPOSIT_AMOUNT}(_stakerRolesIds);
    }

    function test_RegisterWithAdditionalRoles() public {
        test_Register();
        vm.prank(_staker1);

        stakeManager.register(_additionalStakerRolesIds);
        assert(stakeManager.isStakerRegistered(_staker1));
        assert(stakeManager.hasRole(_stakerRolesIds[0], _staker1));
        assert(stakeManager.hasRole(_stakerRolesIds[1], _staker1));
        assert(stakeManager.hasRole(_additionalStakerRolesIds[0], _staker1));
        assertEq(address(stakeManager).balance, DEFAULT_REGISTRATION_DEPOSIT_AMOUNT);
        assertEq(stakeManager.getStakedBalance(_staker1), DEFAULT_REGISTRATION_DEPOSIT_AMOUNT);
        assertEq(address(_staker1).balance, INITIAL_STAKER_WALLET_BALANCE - DEFAULT_REGISTRATION_DEPOSIT_AMOUNT);
    }

    function testFuzz_Register_DifferentAddresses(uint256 stakerId) public {
        vm.assume(stakerId > 3);
        address staker = vm.addr(1);
        vm.deal(staker, INITIAL_STAKER_WALLET_BALANCE);
        vm.prank(staker);
        stakeManager.register{value: DEFAULT_REGISTRATION_DEPOSIT_AMOUNT}(_stakerRolesIds);
        assert(stakeManager.isStakerRegistered(staker));
        assertEq(address(stakeManager).balance, DEFAULT_REGISTRATION_DEPOSIT_AMOUNT);
        assertEq(stakeManager.getStakedBalance(staker), DEFAULT_REGISTRATION_DEPOSIT_AMOUNT);
    }

    function test_Stake() public {
        test_Register();
        vm.prank(_staker1);

        vm.expectEmit();
        emit Staked(_staker1, DEFAULT_STAKE_DEPOSIT_AMOUNT);

        stakeManager.stake{value: DEFAULT_STAKE_DEPOSIT_AMOUNT}();
        assertEq(address(stakeManager).balance, DEFAULT_REGISTRATION_DEPOSIT_AMOUNT + DEFAULT_STAKE_DEPOSIT_AMOUNT);
        assertEq(
            stakeManager.getStakedBalance(_staker1), DEFAULT_REGISTRATION_DEPOSIT_AMOUNT + DEFAULT_STAKE_DEPOSIT_AMOUNT
        );
        assertEq(
            address(_staker1).balance,
            INITIAL_STAKER_WALLET_BALANCE - DEFAULT_REGISTRATION_DEPOSIT_AMOUNT - DEFAULT_STAKE_DEPOSIT_AMOUNT
        );
    }

    function test_StakeRevertIf_NotNotRegisteredStaker() public {
        vm.prank(_staker1);
        vm.expectRevert(NotRegisteredStaker.selector);
        stakeManager.stake{value: DEFAULT_STAKE_DEPOSIT_AMOUNT}();
    }

    function test_StakeRevertIf_NoBalanceToStake() public {
        test_Register();
        vm.prank(_staker1);
        vm.expectRevert(NoBalanceToStake.selector);
        stakeManager.stake();
    }

    function test_Unstake_AfterRegistration() public {
        test_Register();
        vm.prank(_staker1);

        vm.expectEmit();
        emit Unstaked(_staker1, DEFAULT_REGISTRATION_DEPOSIT_AMOUNT, block.timestamp + DEFAULT_WITHDRAWAL_WAIT_TIME);

        stakeManager.unstake();
        assertEq(address(stakeManager).balance, DEFAULT_REGISTRATION_DEPOSIT_AMOUNT);
        assertEq(stakeManager.getStakedBalance(_staker1), 0);
        assertEq(stakeManager.getPendingWithdrawalBalance(_staker1), DEFAULT_REGISTRATION_DEPOSIT_AMOUNT);
    }

    function test_Unstake_AfterStake() public {
        test_Stake();
        vm.prank(_staker1);

        stakeManager.unstake();
        assertEq(address(stakeManager).balance, DEFAULT_REGISTRATION_DEPOSIT_AMOUNT + DEFAULT_STAKE_DEPOSIT_AMOUNT);
        assertEq(stakeManager.getStakedBalance(_staker1), 0);
        assertEq(
            stakeManager.getPendingWithdrawalBalance(_staker1),
            DEFAULT_REGISTRATION_DEPOSIT_AMOUNT + DEFAULT_STAKE_DEPOSIT_AMOUNT
        );
    }

    function test_UnstakeRevertIf_NotRegisteredStaker() public {
        vm.prank(_staker1);
        vm.expectRevert(NotRegisteredStaker.selector);
        stakeManager.unstake();
    }

    function test_UnstakeRevertIf_NotEnoughStakedBalance() public {
        test_Withdraw();
        vm.prank(_staker1);
        vm.expectRevert(NoBalanceToUnstake.selector);
        stakeManager.unstake();
    }

    function test_Withdraw() public {
        test_Unstake_AfterStake();
        skip(DEFAULT_WITHDRAWAL_WAIT_TIME);
        vm.prank(_staker1);

        vm.expectEmit();
        emit Withdrawn(_staker1, DEFAULT_REGISTRATION_DEPOSIT_AMOUNT + DEFAULT_STAKE_DEPOSIT_AMOUNT);

        stakeManager.withdraw();
        assertEq(address(stakeManager).balance, 0);
        assertEq(stakeManager.getStakedBalance(_staker1), 0);
        assertEq(stakeManager.getPendingWithdrawalBalance(_staker1), 0);
        assertEq(address(_staker1).balance, INITIAL_STAKER_WALLET_BALANCE);
    }

    function test_WithdrawRevertIf_NotRegisteredStaker() public {
        test_Unstake_AfterStake();
        skip(DEFAULT_WITHDRAWAL_WAIT_TIME);
        vm.prank(_staker2);
        vm.expectRevert(NotRegisteredStaker.selector);
        stakeManager.withdraw();
    }

    function test_WithdrawRevertIf_WithdrawalWaitTimeNotPassed() public {
        test_Unstake_AfterStake();
        vm.prank(_staker1);
        vm.expectRevert(WithdrawalWaitTimeNotPassed.selector);
        stakeManager.withdraw();
    }

    //test withdrawal expect revert NoBalanceToWithdraw
    function test_WithdrawRevertIf_NoBalanceToWithdraw() public {
        test_Withdraw();
        vm.prank(_staker1);
        vm.expectRevert(NoBalanceToWithdraw.selector);
        stakeManager.withdraw();
    }

    function test_Unregister() public {
        test_Withdraw();
        vm.prank(_staker1);

        vm.expectEmit();
        emit Unregistered(_staker1);

        stakeManager.unregister();
        assert(!stakeManager.isStakerRegistered(_staker1));
        assert(!stakeManager.hasRole(_stakerRolesIds[0], _staker1));
        assert(!stakeManager.hasRole(_stakerRolesIds[1], _staker1));
        assertEq(address(stakeManager).balance, 0);
        assertEq(stakeManager.getStakedBalance(_staker1), 0);
    }

    function test_UnregisterRevertIf_NotRegisteredStaker() public {
        vm.prank(_staker1);
        vm.expectRevert(NotRegisteredStaker.selector);
        stakeManager.unregister();
    }

    function test_UnregisterRevertIf_StakerBalanceIsNonZero() public {
        test_Stake();
        vm.prank(_staker1);
        vm.expectRevert(BalanceIsNonZero.selector);
        stakeManager.unregister();
    }

    function test_UnregisterRevertIf_PendingWithdrawalBalanceIsNonZero() public {
        test_Unstake_AfterStake();
        vm.prank(_staker1);
        vm.expectRevert(PendingWithdrawalBalanceIsNonZero.selector);
        stakeManager.unregister();
    }

    function test_Slash() public {
        test_Register();

        stakeManager.slash(_staker1, DEFAULT_REGISTRATION_DEPOSIT_AMOUNT / 2);
        assert(stakeManager.isStakerRegistered(_staker1));
        assert(stakeManager.hasRole(_stakerRolesIds[0], _staker1));
        assert(stakeManager.hasRole(_stakerRolesIds[1], _staker1));
        assertEq(address(stakeManager).balance, DEFAULT_REGISTRATION_DEPOSIT_AMOUNT);
        assertEq(stakeManager.getStakedBalance(_staker1), DEFAULT_REGISTRATION_DEPOSIT_AMOUNT / 2);
    }

    function test_SlashRevertWhen_AmountIsZero() public {
        test_Register();
        vm.expectRevert(ZeroAmount.selector);
        stakeManager.slash(_staker1, 0);
    }

    function test_SlashRevertWhen_NotRegisteredStaker() public {
        test_Register();
        vm.expectRevert(NotRegisteredStaker.selector);
        stakeManager.slash(_staker2, DEFAULT_REGISTRATION_DEPOSIT_AMOUNT / 2);
    }

    function test_SlashRevertWhen_NotEnoughStakedBalance() public {
        test_Register();
        vm.expectRevert(NoBalanceToSlash.selector);
        stakeManager.slash(_staker1, DEFAULT_REGISTRATION_DEPOSIT_AMOUNT + 1);
    }

    function test_WithdrawEtherByAdmin() public {
        test_Slash();

        stakeManager.withdrawEtherByAdmin(_staker2);
        assertEq(address(stakeManager).balance, DEFAULT_REGISTRATION_DEPOSIT_AMOUNT / 2);
        assertEq(stakeManager.getStakedBalance(_staker1), DEFAULT_REGISTRATION_DEPOSIT_AMOUNT / 2);
        assertEq(stakeManager.getPendingWithdrawalBalance(_staker1), 0);
        assertEq(address(_staker2).balance, INITIAL_STAKER_WALLET_BALANCE + DEFAULT_REGISTRATION_DEPOSIT_AMOUNT / 2);
    }

    function test_WithdrawEtherByAdminRevertIf_NoSlashedBalanceToWithdraw() public {
        test_Register();
        vm.expectRevert(NoSlashedBalanceToWithdraw.selector);
        stakeManager.withdrawEtherByAdmin(_staker1);
    }

    function test_WithdrawEtherByAdminRevertIf_RecipientIsZeroAddress() public {
        test_Slash();
        vm.expectRevert(ZeroAddress.selector);
        stakeManager.withdrawEtherByAdmin(address(0x0));
    }

    function invariant_AdminRoleIsStable() public {
        excludeSender(address(this));
        assertEq(stakeManager.hasRole(stakeManager.DEFAULT_ADMIN_ROLE(), address(this)), true);
    }

    function invariant_ContractBalanceEGTThanStakers() public {
        targetSender(_staker1);
        targetSender(_staker2);
        targetSender(_staker3);
        assert(address(stakeManager).balance >= stakeManager.getStakedBalance(_staker1));
        assert(address(stakeManager).balance >= stakeManager.getStakedBalance(_staker1));
    }
}
