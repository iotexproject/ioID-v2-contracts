// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {DeviceNFTTemplate} from "./DeviceNFTTemplate.sol";

contract DeviceNFTFactory {
    address public immutable IMPLEMENTATION;

    event DeviceNFTContractCreated(address deviceNFT);

    constructor(address _implementation) {
        IMPLEMENTATION = _implementation;
    }

    function createDeviceNFT(string memory name, string memory symbol, address owner, address operator) external returns (address) {
        address clone = Clones.clone(IMPLEMENTATION);

        DeviceNFTTemplate(clone).initialize(name, symbol, owner,  operator);

        emit DeviceNFTContractCreated(clone);

        return clone;
    }
}
