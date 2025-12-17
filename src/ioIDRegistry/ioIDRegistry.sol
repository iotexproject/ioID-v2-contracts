// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {NFTMapping} from "./abstract/NFTMapping.sol";
import {DIDDocMapping} from "./abstract/DIDDocMapping.sol";
import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract IoIDRegistry is UUPSUpgradeable, Ownable2StepUpgradeable, NFTMapping, DIDDocMapping {
    
    /// @notice Address authorized to register devices
    address public operator;
    
    /// @notice Total number of registered devices
    uint256 public totalDevices;
    
    modifier onlyOperator() {
        require(msg.sender == operator, "Not operator");
        _;
    }

    function setOperator(address _operator) public onlyOwner {
        require(_operator != address(0), "Operator cannot be zero address");
        operator = _operator;
    }
    
    function initialize(address owner) public initializer  {
        __Ownable_init(owner);
        __Ownable2Step_init();
        __UUPSUpgradeable_init();
        operator = owner;
    }

    /// @notice Authorizes contract upgrades - only owner can upgrade
    /// @param newImplementation The address of the new implementation contract
    /// @dev This function is required by UUPSUpgradeable to control who can upgrade the contract
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /// @notice Registers a device NFT with basic information
    /// @param ioIDIdentifier The unique identifier for the device (must not be zero)
    /// @param chainID The blockchain ID where the NFT is deployed
    /// @param NFTcontract The contract address in bytes format (must be 20 bytes for Ethereum or 32 bytes for Solana)
    /// @param tokenID The token ID of the NFT
    function registerDeviceNFT(
        bytes32 ioIDIdentifier,
        uint256 chainID,
        bytes memory NFTcontract,
        uint256 tokenID
    ) public onlyOperator {
        bool isNewDevice = _setDeviceNFT(ioIDIdentifier, chainID, NFTcontract, tokenID);
        if (isNewDevice) {
            totalDevices++;
        }
    }

    /// @notice Registers a device NFT with both basic information and DID metadata
    /// @param ioIDIdentifier The unique identifier for the device (must not be zero)
    /// @param chainID The blockchain ID where the NFT is deployed
    /// @param NFTcontract The contract address in bytes format (must be 20 bytes for Ethereum or 32 bytes for Solana)
    /// @param tokenID The token ID of the NFT
    /// @param didUri The DID URI for the device
    /// @param didHash The hash of the DID document
    function registerDeviceNFTWithDIDDoc(
        bytes32 ioIDIdentifier,
        uint256 chainID,
        bytes memory NFTcontract,
        uint256 tokenID,
        string memory didUri,
        bytes32 didHash
    ) public onlyOperator {
        registerDeviceNFT(ioIDIdentifier, chainID, NFTcontract, tokenID);
        _setDIDDocMetadata(ioIDIdentifier, didUri, didHash);
    }

    /// @notice Deletes a device NFT and its associated DID metadata
    /// @param ioIDIdentifier The unique identifier for the device to delete
    function deleteDeviceNFT(
        bytes32 ioIDIdentifier
    ) public onlyOwner {
        bool existed = _deleteDeviceNFT(ioIDIdentifier);
        _deleteDIDDocMetadata(ioIDIdentifier);
        if (existed) {
            totalDevices--;
        }
    }

}