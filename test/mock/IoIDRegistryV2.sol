// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {NFTMapping} from "../../src/ioIDRegistry/abstract/NFTMapping.sol";
import {DIDDocMapping} from "../../src/ioIDRegistry/abstract/DIDDocMapping.sol";
import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract IoIDRegistryV2 is UUPSUpgradeable, Ownable2StepUpgradeable, NFTMapping, DIDDocMapping {
    
    address public operator;
    
    uint256 public totalDevices;
    
    uint256 public newVar;

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

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function registerDeviceNFT(
        bytes32 ioIDIdentifier,
        uint256 chainID,
        bytes memory NFTcontract,
        uint256 tokenID
    ) public onlyOperator {
        require(chainID != 0, "Chain ID cannot be zero");
        bool isNewDevice = _setDeviceNFT(ioIDIdentifier, chainID, NFTcontract, tokenID);
        if (isNewDevice) {
            totalDevices++;
        }
    }

    function registerDeviceNFTWithDIDDoc(
        bytes32 ioIDIdentifier,
        uint256 chainID,
        bytes memory NFTcontract,
        uint256 tokenID,
        string memory didUri,
        bytes32 didHash
    ) public onlyOperator {
        require(chainID != 0, "Chain ID cannot be zero");
        registerDeviceNFT(ioIDIdentifier, chainID, NFTcontract, tokenID);
        _setDIDDocMetadata(ioIDIdentifier, didUri, didHash);
    }

    function deleteDeviceNFT(
        bytes32 ioIDIdentifier
    ) public onlyOwner {
        bool existed = _deleteDeviceNFT(ioIDIdentifier);
        _deleteDIDDocMetadata(ioIDIdentifier);
        if (existed) {
            totalDevices--;
        }
    }
    
    /// @notice New state variable added in V2
    mapping(bytes32 => string) private _deviceDescriptions;
    
    /// @notice Event emitted when device description is updated
    event DeviceDescriptionUpdated(bytes32 indexed ioIDIdentifier, string description);
    
    /// @notice Sets a description for a registered device
    /// @param ioIDIdentifier The unique identifier for the device
    /// @param description The description to set for the device
    function setDeviceDescription(bytes32 ioIDIdentifier, string memory description) public onlyOwner {
        require(ioIDIdentifier != bytes32(0), "Invalid ioID identifier");
        _deviceDescriptions[ioIDIdentifier] = description;
        emit DeviceDescriptionUpdated(ioIDIdentifier, description);
    }
    
    /// @notice Gets the description for a registered device
    /// @param ioIDIdentifier The unique identifier for the device
    /// @return description The description of the device
    function getDeviceDescription(bytes32 ioIDIdentifier) public view returns (string memory description) {
        return _deviceDescriptions[ioIDIdentifier];
    }
    
    /// @notice Registers a device NFT with description
    /// @param ioIDIdentifier The unique identifier for the device
    /// @param chainID The blockchain ID where the NFT is deployed
    /// @param NFTcontract The contract address in bytes format
    /// @param tokenID The token ID of the NFT
    /// @param description The description for the device
    function registerDeviceNFTWithDescription(
        bytes32 ioIDIdentifier,
        uint256 chainID,
        bytes memory NFTcontract,
        uint256 tokenID,
        string memory description
    ) public onlyOwner {
        require(chainID != 0, "Chain ID cannot be zero");
        registerDeviceNFT(ioIDIdentifier, chainID, NFTcontract, tokenID);
        setDeviceDescription(ioIDIdentifier, description);
    }
    
    /// @notice Returns the version of the contract
    /// @return version The version string
    function version() public pure returns (string memory) {
        return "2.0.0";
    }

    function setNewVar(uint256 _val) public onlyOwner {
        newVar = _val;
    }
} 