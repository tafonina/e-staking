// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IStakeManager} from "./interfaces/IStakeManager.sol";
import {IStakeManagerEvents} from "./interfaces/IStakeManagerEvents.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

error AdminRoleNotGranted();
error NotRegisteredStaker();
error NotEnoughDepositAmount();
error NoBalanceToUnstake();
error NoBalanceToSlash();
error ZeroAddress();
error RoleDoesntExist();
error NoBalanceToStake();
error BalanceIsNonZero();
error PendingWithdrawalBalanceIsNonZero();
error FailedTransfer();
error AlreadyRegisteredRole();
error WithdrawalWaitTimeNotPassed();
error NoSlashedBalanceToWithdraw();
error NoBalanceToWithdraw();
error ZeroAmount();

// @assume only basic events are required Registered, Unregistered, Staked, Unstaked, Withdrawn, Slashed,
//      all other are not required within the task
// @assume that additional roles besides ADMIN role could be required for extended functionality,
//      so we use AccessControlUpgradeable instead of OwnableUpgradeable
// @assume that user can unstake the whole balance at once
// @assume that user can withdraw the whole pending balance at once
// @assume that when user calls unstake even if previous unstake/withdrawal is not finished.
//      the sped bump for withdrawal is increased according to such logic:
//          withdrawalTimestamp = block.timestamp + _withdrawalWaitTime
//      So each time calling unstake the pending balance is accumulated with current balance and withdrawalTimestamp is updated
// @assume that user need to deposit min _registrationDepositAmount only if it is not registered for any staker role yet
// @assume we don't care if sent amount is more than the _registrationDepositAmount during registration
// @assume staker is able to send any amount of additonal ether during not-first-time registration,
//      it should be added to the staker's balance
// @assume the deposited amount during registration is added to the staker's balance (it is not system fee)
// @assume that admin can manage staker roles only by adding a new ones and can not remove them
// How to store staker's roles depends on requirements which is not set within the task
// @assume staker's roles are manageble via AccessControlUpgradeable,
//      it means that admin can add assign/unassign them to stakers
//          (=> can lead to the case when admin revoke stakers roles and staker can not unstake and withdraw the balance)
//      but if admin should not be able to assign/unassign staker's roles for stakers:
//          we could use BitMaps.BitMap rolesBitMap to store staker's roles, so only staker decide which role to assign
// @assume if ADMIN will grant some staker role to the account,
//      the account will be able to register for one more role without _registrationDepositAmount

contract StakeManager is Initializable, AccessControlUpgradeable, IStakeManager, IStakeManagerEvents {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    struct Staker {
        uint256 balance; // staker's balance (does not include pending withdrawal balance)
        uint256 balancePendingWithdrawal; // pending balance to be withdrawn when withdrawalTimestamp is passed
        uint256 withdrawalTimestamp; // timestamp shows when user is able to withdraw the pending balance
    }

    // constant staker roles
    bytes32 public constant STAKER_ROLE1 = keccak256("STAKER_ROLE1");
    bytes32 public constant STAKER_ROLE2 = keccak256("STAKER_ROLE2");
    bytes32 public constant STAKER_ROLE3 = keccak256("STAKER_ROLE3");

    uint256 private _registrationDepositAmount; // initial registration deposit amount in wei
    uint256 private _withdrawalWaitTime; // speed bump, the duration a staker must wait after unstake before withdrawal
    uint256 private _slashedTotalAmount; // total amount of slashed ether
    mapping(address => Staker) private _stakers; // stakers mapping

    /**
     * @dev modifier to check if the address is not zero
     */
    modifier onlyAdmin() {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert AdminRoleNotGranted();
        }
        _;
    }

    /**
     * @dev modifier to check if staker is registered, has at least one staker role
     */
    modifier onlyRegisteredStaker() {
        if (!isStakerRegistered(msg.sender)) {
            revert NotRegisteredStaker();
        }
        _;
    }

    /**
     * @dev modifier to check if the address is not zero
     * @param account The address to be checked.
     */
    modifier nonZeroAddress(address account) {
        if (account == address(0)) {
            revert ZeroAddress();
        }
        _;
    }

    /**
     * @dev     modifier to check if withdrawalTimestamp is passed for the staker
     */
    modifier passedWithdrawalTimestamp() {
        if (block.timestamp < _stakers[msg.sender].withdrawalTimestamp) {
            revert WithdrawalWaitTimeNotPassed();
        }
        _;
    }

    /**
     * @dev Initializes the contract.
     * @param registrationDepositAmount Initial registration deposit amount in wei.
     * @param withdrawalWaitTime The duration a staker must wait after initiating registration.
     */
    function initialize(uint256 registrationDepositAmount, uint256 withdrawalWaitTime) public initializer {
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setConfiguration(registrationDepositAmount, withdrawalWaitTime);
    }

    /**
     * @dev Allows an admin to set the configuration of the staking contract.
     * @param registrationDepositAmount Initial registration deposit amount in wei.
     * @param withdrawalWaitTime The duration a staker must wait after initiating registration.
     */
    function setConfiguration(uint256 registrationDepositAmount, uint256 withdrawalWaitTime)
        external
        override
        onlyAdmin
    {
        _setConfiguration(registrationDepositAmount, withdrawalWaitTime);
    }

    /**
     * @dev Allows an account to register as a staker,
     *     if staker is not registered before - the _registrationDepositAmount should be deposited
     * @param rolesIds The roles array that the staker wants to have.
     */
    function register(bytes32[] memory rolesIds) external payable override {
        // check if staker is not registered - if so, check if deposit amount is enough
        if (!isStakerRegistered(msg.sender) && msg.value < _registrationDepositAmount) {
            revert NotEnoughDepositAmount();
        }
        _register(msg.sender, rolesIds);

        if (msg.value > 0) {
            _stake(msg.sender, msg.value);
        }
    }

    /**
     * @dev Allows a registered staker to unregister and exit the staking system.
     */
    function unregister() external override onlyRegisteredStaker {
        // check if staker has no balance
        if (_stakers[msg.sender].balance > 0) {
            revert BalanceIsNonZero();
        }
        // check if pending withdrawal balance is zero
        if (_stakers[msg.sender].balancePendingWithdrawal > 0) {
            revert PendingWithdrawalBalanceIsNonZero();
        }
        _unregister(msg.sender);
    }

    /**
     * @dev Allows registered stakers to stake ether into the contract.
     */
    function stake() external payable override onlyRegisteredStaker {
        _stake(msg.sender, msg.value);
    }

    /**
     * @dev Allows registered stakers to unstake their ether from the contract.
     */
    function unstake() external override onlyRegisteredStaker {
        _unstakeAll(msg.sender);
    }

    /**
     * @dev Allows registered stakers to withdraw the unstaked ether from the contract
     */
    function withdraw() external override onlyRegisteredStaker passedWithdrawalTimestamp {
        _withdrawAll(msg.sender);
    }

    /**
     * @dev Allows an admin to slash a portion of the staked ether of a given staker.
     * @param staker The address of the staker to be slashed.
     * @param amount The amount of ether to be slashed from the staker.
     */
    function slash(address staker, uint256 amount) external override onlyAdmin {
        if (!isStakerRegistered(staker)) {
            revert NotRegisteredStaker();
        }
        // balance should be > 0
        if (_stakers[staker].balance < amount) {
            revert NoBalanceToSlash();
        }
        if (amount == 0) {
            revert ZeroAmount();
        }

        _stakers[staker].balance -= amount;
        _slashedTotalAmount += amount;
        emit Slashed(staker, amount, msg.sender);
    }

    /**
     * @dev Allows admin to withdraw the whole slashed balance from the contract
     * @param recipient The address of the recipient to be withdrawn.
     */
    function withdrawEtherByAdmin(address recipient) external onlyAdmin nonZeroAddress(recipient) {
        if (_slashedTotalAmount == 0) {
            revert NoSlashedBalanceToWithdraw();
        }
        uint256 amount = _slashedTotalAmount;
        _slashedTotalAmount = 0;
        (bool success,) = payable(recipient).call{gas: 200_000, value: amount}("");
        if (!success) {
            revert FailedTransfer();
        }
    }

    /**
     * @dev Returns the staked balance of a staker.
     * @param staker The address of the staker to be checked.
     * @return The staked balance of the staker.
     */
    function getStakedBalance(address staker) external view returns (uint256) {
        return _stakers[staker].balance;
    }

    /**
     * @dev Returns the pending withdrawal balance of a staker.
     * @param staker The address of the staker to be checked.
     * @return The pending withdrawal balance of the staker.
     */
    function getPendingWithdrawalBalance(address staker) external view returns (uint256) {
        return _stakers[staker].balancePendingWithdrawal;
    }

    /**
     * @dev Returns the registration deposit amount.
     * @return The registration deposit amount.
     */
    function getRegistrationDepositAmount() external view returns (uint256) {
        return _registrationDepositAmount;
    }

    /**
     * @dev Returns the withdrawal wait time.
     * @return The withdrawal wait time.
     */
    function getWithdrawalWaitTime() external view returns (uint256) {
        return _withdrawalWaitTime;
    }

    /**
     * @dev Checks if the staker is registered, i.e. has any of the staker roles.
     * @param staker The address of the staker to be checked.
     * @return True if the staker is registered.
     */
    function isStakerRegistered(address staker) public view returns (bool) {
        return _hasAnyStakerRole(staker);
    }

    /**
     * @dev set the configuration of the staking contract internal method
     * @param registrationDepositAmount Initial registration deposit amount in wei.
     * @param withdrawalWaitTime The duration a staker must wait after initiating registration.
     */
    function _setConfiguration(uint256 registrationDepositAmount, uint256 withdrawalWaitTime) internal {
        _registrationDepositAmount = registrationDepositAmount;
        _withdrawalWaitTime = withdrawalWaitTime;
    }

    /**
     * @dev Internal method to register the staker and add to the staking system.
     * @param staker The address of the staker to be registered.
     * @param rolesIds The array of staker roles ids to be registered.
     */
    function _register(address staker, bytes32[] memory rolesIds) internal {
        // add staker's roles
        for (uint256 i = 0; i < rolesIds.length;) {
            _setStakerRole(staker, rolesIds[i]);
            unchecked {
                i += 1;
            }
        }
        emit Registered(staker, rolesIds);
    }

    /**
     * @dev Internal method to unregister the staker and exit the staking system.
     * @param staker The address of the staker to be unregistered.
     */
    function _unregister(address staker) internal {
        // remove all staker's roles
        //check if staker has role and revoke it
        _unsetStakerRole(staker, STAKER_ROLE1);
        _unsetStakerRole(staker, STAKER_ROLE2);
        _unsetStakerRole(staker, STAKER_ROLE3);

        emit Unregistered(staker);
    }

    /**
     * @dev Internal method to stake, can check for minimum amount to be on staker's balance is needed as extended functionlaity
     */
    function _stake(address staker, uint256 amount) internal {
        if (amount == 0) {
            revert NoBalanceToStake();
        }
        _stakers[staker].balance += amount;
        emit Staked(staker, amount);
    }

    /**
     * @dev Internal method to unstake the whole staked balance from the contract,
     *         it will be added to the pending withdrawal balance and can be withdrawn with speed bump_withdrawalWaitTime
     * @param staker The address of the staker to be unstaked.
     */
    function _unstakeAll(address staker) internal {
        uint256 balance = _stakers[staker].balance;
        // balance should be > 0
        if (balance == 0) {
            revert NoBalanceToUnstake();
        }
        _stakers[staker].balance = 0;
        // increment to pending withdrawal balance even if it is non zero
        _stakers[staker].balancePendingWithdrawal += balance;
        // update withdrawalTimestamp even if previous not passes (according to assumptions)
        _stakers[staker].withdrawalTimestamp = block.timestamp + _withdrawalWaitTime;
        emit Unstaked(staker, balance, _stakers[staker].withdrawalTimestamp);
    }

    /**
     * @dev Internal method to withdraw all the unstaked staker's ether from the contract
     * @param staker The address of the staker to be withdrawn.
     */
    function _withdrawAll(address staker) internal {
        uint256 balancePendingWithdrawal = _stakers[msg.sender].balancePendingWithdrawal;

        if (balancePendingWithdrawal == 0) {
            revert NoBalanceToWithdraw();
        }
        _stakers[staker].balancePendingWithdrawal = 0;
        emit Withdrawn(staker, balancePendingWithdrawal);
        // transfer ether to the staker
        (bool success,) = payable(staker).call{value: balancePendingWithdrawal}("");
        if (!success) {
            revert FailedTransfer();
        }
    }

    /**
     * @dev Internal method to revoke a staker role from an account via openzeppelin access control
     * @param staker The address of the staker to be revoked the role.
     * @param roleId The id of the role to be revoked.
     */
    function _unsetStakerRole(address staker, bytes32 roleId) internal {
        // call _revokeRole only if staker has this role
        if (hasRole(roleId, staker)) {
            _revokeRole(roleId, staker);
        }
    }

    /**
     * @dev Grants a staker role to an account via openzeppelin access control
     * @param staker The address of the staker to be granted the role.
     * @param roleId The id of the role to be granted.
     */
    function _setStakerRole(address staker, bytes32 roleId) internal {
        // procced only if role exists in system
        if (roleId != STAKER_ROLE1 && roleId != STAKER_ROLE2 && roleId != STAKER_ROLE3) {
            revert RoleDoesntExist();
        }
        // proceed only if staker has not this role yet
        if (hasRole(roleId, staker)) {
            revert AlreadyRegisteredRole();
        }
        _grantRole(roleId, staker);
    }

    /**
     * @dev Checks if the staker has any of the staker roles via access control
     * @param staker The address of the staker to be checked.
     */
    function _hasAnyStakerRole(address staker) internal view returns (bool) {
        return hasRole(STAKER_ROLE1, staker) || hasRole(STAKER_ROLE2, staker) || hasRole(STAKER_ROLE3, staker);
    }
}
