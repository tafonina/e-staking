// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IStakeManagerEvents {
    event Registered(address indexed staker, bytes32[] rolesIds);
    event Unregistered(address indexed staker);
    event Staked(address indexed staker, uint256 amount);
    event Unstaked(address indexed staker, uint256 amount, uint256 withdrawalTimestamp);
    event Withdrawn(address indexed staker, uint256 amount);
    event Slashed(address indexed staker, uint256 amount, address indexed admin);
}
