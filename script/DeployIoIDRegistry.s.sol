// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {IoIDRegistry} from "../src/ioIDRegistry/ioIDRegistry.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployIoIDRegistry is Script {
    function run() external returns (address) {
        // Read private key from environment variable
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy Implementation
        IoIDRegistry implementation = new IoIDRegistry();
        console.log("IoIDRegistry implementation deployed at:", address(implementation));

        // 2. Prepare initialization data
        bytes memory initData = abi.encodeWithSelector(
            IoIDRegistry.initialize.selector,
            deployer // owner
        );

        // 3. Deploy Proxy
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        console.log("IoIDRegistry proxy deployed at:", address(proxy));

        vm.stopBroadcast();
        return address(proxy);
    }
} 