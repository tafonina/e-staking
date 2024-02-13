// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {StakeManager} from "../src/StakeManager.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract DeployProxy is Script {
    // private key is the same for everyone
    uint256 public deployerKey;

    function run() external returns (address) {
        deployerKey = vm.envUint("PRIVATE_KEY");

        address proxy = deployProxy(vm.addr(deployerKey));

        return proxy;
    }

    function deployProxy(address _admin) public returns (address) {
        vm.startBroadcast(_admin);

        address proxy =
            Upgrades.deployUUPSProxy("StakeManager.sol", abi.encodeCall(StakeManager.initialize, (100, 100)));

        vm.stopBroadcast();
        return address(proxy);
    }
}
