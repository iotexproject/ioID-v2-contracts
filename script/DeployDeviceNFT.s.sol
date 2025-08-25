// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {DeviceNFTFactory} from "../src/deviceNFT/DeviceNFTFactory.sol";
import {DeviceNFTTemplate} from "../src/deviceNFT/DeviceNFTTemplate.sol";

contract DeployDeviceNFT is Script {
    DeviceNFTTemplate public deviceNFTTemplate;
    DeviceNFTFactory public deviceNFTFactory;

    function run() external returns (DeviceNFTTemplate, DeviceNFTFactory) {
        vm.startBroadcast();

        // Deploy the DeviceNFTTemplate (implementation contract)
        deviceNFTTemplate = new DeviceNFTTemplate();
        console2.log("DeviceNFTTemplate deployed at:", address(deviceNFTTemplate));

        // Deploy the DeviceNFTFactory with the template address
        deviceNFTFactory = new DeviceNFTFactory(address(deviceNFTTemplate));
        console2.log("DeviceNFTFactory deployed at:", address(deviceNFTFactory));

        vm.stopBroadcast();

        // Log deployment summary
        console2.log("=== Deployment Summary ===");
        console2.log("DeviceNFTTemplate (Implementation):", address(deviceNFTTemplate));
        console2.log("DeviceNFTFactory:", address(deviceNFTFactory));
        console2.log("Factory Implementation:", deviceNFTFactory.IMPLEMENTATION());

        return (deviceNFTTemplate, deviceNFTFactory);
    }
}
