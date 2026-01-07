// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {IoIDRegistryBatchWrapper} from "../src/ioIDRegistry/ioIDRegistryBatchWrapper.sol";

contract DeployIoIDRegistryBatchWrapper is Script {
    // Contract addresses from const.ts
    address constant IOID_REGISTRY_CONTRACT = 0x8924a4457F3A5D45079541793158E9E668a1141b;
    address constant ACCOUNT_REGISTRY_CONTRACT = 0x000000006551c19487814612e58FE06813775758;
    address constant ACCOUNT_IMPLEMENTATION_PROXY = 0xb59b64Bb12f1E68d646FDE8e51C89f02bd479E73;
    address constant ACCOUNT_IMPLEMENTATION_UPGRADABLE = 0x471C226dB08F0e8C576083Dd3b8C856edb05420C; // You need to provide this
    bytes32 constant ACCOUNT_SALT = 0x0000000000000000000000000000000000000000000000000000000000000000;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);

        IoIDRegistryBatchWrapper batchWrapper = new IoIDRegistryBatchWrapper(
            IOID_REGISTRY_CONTRACT,
            ACCOUNT_REGISTRY_CONTRACT,
            ACCOUNT_IMPLEMENTATION_PROXY,
            ACCOUNT_IMPLEMENTATION_UPGRADABLE,
            ACCOUNT_SALT
        );

        console.log("IoIDRegistryBatchWrapper deployed at:", address(batchWrapper));
        console.log("IoID Registry:", batchWrapper.ioIDRegistry());
        console.log("ERC6551 Registry:", batchWrapper.erc6551Registry());
        console.log("Account Implementation Proxy:", batchWrapper.accountImplementationProxy());
        console.log("Account Implementation Upgradable:", batchWrapper.accountImplementationUpgradable());

        vm.stopBroadcast();
    }
}
