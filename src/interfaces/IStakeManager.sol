// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IStakeManager {
    /**
     * @dev Allows an admin to set the configuration of the staking contract.
     * @param registrationDepositAmount Initial registration deposit amount in wei.
     * @param registrationWaitTime The duration a staker must wait after initiating registration.
     */
    function setConfiguration(uint256 registrationDepositAmount, uint256 registrationWaitTime) external;

    /**
     * @dev Allows an account to register as a staker.
     * @param rolesIds The roles array that the staker wants to have.
     */
    function register(bytes32[] memory rolesIds) external payable;

    /**
     * @dev Allows a registered staker to unregister and exit the staking system.
     */
    function unregister() external;

    /**
     * @dev Allows registered stakers to stake ether into the contract.
     */
    function stake() external payable;

    /**
     * @dev Allows registered stakers to unstake their ether from the contract.
     */
    function unstake() external;

    /**
     * @dev Allows registered stakers to withdraw the unstaked ether from the contract
     */
    function withdraw() external;

    /**
     * @dev Allows an admin to slash a portion of the staked ether of a given staker.
     * @param staker The address of the staker to be slashed.
     * @param amount The amount of ether to be slashed from the staker.
     */
    function slash(address staker, uint256 amount) external;
}
