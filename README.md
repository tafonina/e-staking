[Usage](#usage)
[Task Description](#description)
[Assumptions](#assumptions)


## Usage

### Install dependencies
```shell
yarn install
```

### Build

```shell
yarn build
```

or via forge directly:
```shell
forge build
```

### Test

via yarn:

```shell
yarn test
```

or via forge directly:
```shell
forge test
```

### Coverage

via yarn:
```shell
yarn coverage
```

or via forge directly:
```shell
forge coverage
```

### Deploy

Create .env file on base of .env.example and specify needed variables.
Run deploy:

via yarn:
```shell
yarn deploy
```

or via forge directly:
```shell
source .env && forge script script/StakeManager.s.sol:DeployProxy --rpc-url $RPC_URL --private-key $PRIVATE_KEY --verify --etherscan-api-key $ETHERSCAN_API_KEY --broadcast -vvvv --ffi
```

## Task Description

### Assignment Specifications
Task
Your task is to write a smart contract in Solidity that implements the IStakeManager interface. Note that in the interface given below all signatures are with no parameters but feel free to change that to your needs. This contract should manage staking functionality within a system, including registration, configuration management, staking, unstaking, and slashing mechanisms.
Roles and Registration

- Stakers can register, unregister, and be slashed.
- A staker can register for one or more roles. This is done using the register method. A user can register multiple times but on the first registration they need to provide a minimal amount of wei (described below in the configuration management). If this is a second registration and the user has the minimal needed stake it should not require an additional deposit.
- A stake can use the stake() function to add additional stake to the system without modifying their roles.
A user can unstake their funds. In this case the funds will be locked a configured period of time before the stake can withdraw them using the withdraw function (see the section below).
- A user can unregister from the system when their stake is zero and they are not pending withdrawal. Once unregistered all roles are revoked.
- The roles in this exercise are abstract and have no actual usage. It should be easy to identify which role each staker has but that’s about it. You can think of roles as different responsibilities the system gives to different stakers. One staker can have a certain type of tasks  while others might have some different responsibilities, their actual implementation is not in the scope of this exercise.


###  Configuration Management

- The configuration should control which roles exist in the system.
- It should specify how much wei a staker should deposit upon registration.
- It should define how long the user has to wait between unstaking and withdrawing their staked balance. (this is to protect the system from people trying to do some wrongful act and exit with their funds immediately)



### Requirements
Implementation: Your contract must implement all functions in the IStakeManager interface.


#### Access Control:
The register function should be callable by anyone. 
The stake function should be restricted to stakers only.
The unstake function should be restricted to stakers only.
The slash function should be restricted to an admin role.
The withdraw function should be restricted to stakers only.
Ensure that only authorized users can configure the system.

**Testing**: Include comprehensive unit tests using Cast / Foundry.


Upgradeability: The contract should be upgradeable.
Documentation: Provide clear documentation on how to deploy, interact with, and test the contract.
Submission Guidelines
Repository: Submit your project in a GitHub repository.
EVM Compatibility: Ensure the project is compatible with an EVM-compliant blockchain.
Assumptions: Document any assumptions made during the development process.


## Assumptions

 - @assume only basic events are required Registered, Unregistered, Staked, Unstaked, Withdrawn, Slashed,
      all other are not required within the task
 - @assume that additional roles besides ADMIN role could be required for extended functionality,
      so we use AccessControlUpgradeable instead of OwnableUpgradeable
 - @assume that user can unstake the whole balance at once
 - @assume that user can withdraw the whole pending balance at once
 - @assume that when user calls unstake even if previous unstake/withdrawal is not finished.
      the sped bump for withdrawal is increased according to such logic:
          withdrawalTimestamp = block.timestamp + _withdrawalWaitTime
      So each time calling unstake the pending balance is accumulated with current balance and withdrawalTimestamp is updated
 - @assume that user need to deposit min _registrationDepositAmount only if it is not registered for any staker role yet
 - @assume we don't care if sent amount is more than the _registrationDepositAmount during registration
 - @assume staker is able to send any amount of additonal ether during not-first-time registration,
      it should be added to the staker's balance
 - @assume the deposited amount during registration is added to the staker's balance (it is not system fee)
 - @assume that admin can manage staker roles only by adding a new ones and can not remove them
 How to store staker's roles depends on requirements which is not set within the task
 - @assume staker's roles are manageble via AccessControlUpgradeable,
      it means that admin can add assign/unassign them to stakers
          (=> can lead to the case when admin revoke stakers roles and staker can not unstake and withdraw the balance)
      but if admin should not be able to assign/unassign staker's roles for stakers:
          we could use BitMaps.BitMap rolesBitMap to store staker's roles, so only staker decide which role to assign
 - @assume if ADMIN will grant some staker role to the account,
      the account will be able to register for one more role without _registrationDepositAmount