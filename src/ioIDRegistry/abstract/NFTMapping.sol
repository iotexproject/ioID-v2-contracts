// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

abstract contract NFTMapping {
    
    /// @notice Structure to store NFT information
    /// @param chainID The ID of the blockchain where the NFT is deployed
    /// @param NFTcontract The contract address in bytes format (20 bytes for Ethereum, 32 bytes for Solana)
    /// @param tokenID The unique token identifier of the NFT
    struct DeviceNFT {
        uint256 chainID;
        bytes NFTcontract;
        uint256 tokenID;
    }
    
    /// @custom:storage-location erc7201:nftmapping.storage
    struct NFTMappingStorage {
        mapping(bytes32 => DeviceNFT) _ioidNFTMapping;
    }

    // keccak256(abi.encode(uint256(keccak256("nftmapping.storage")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant NFT_MAPPING_STORAGE_LOCATION = 
        0x5455eb79b52a9369dc7c3979a966de6db7d40a37d193efc6fa439e4926af6000;
    
    function _getNFTMappingStorage() private pure returns (NFTMappingStorage storage $) {
        assembly {
            $.slot := NFT_MAPPING_STORAGE_LOCATION
        }
    }
    
    /// @notice Event emitted when a device NFT is registered or updated
    /// @param ioIDIdentifier The unique identifier for the device
    /// @param chainID The blockchain ID where the NFT is deployed
    /// @param NFTcontract The contract address in bytes format
    /// @param tokenID The token ID of the NFT
    event DeviceNFTUpdated(
        bytes32 indexed ioIDIdentifier,
        uint256 chainID,
        bytes NFTcontract,
        uint256 tokenID
    );

    event DeviceNFTDeleted(
        bytes32 ioIDIdentifier
    );

    /// @notice Internal function to set a device NFT
    /// @param ioIDIdentifier The unique identifier for the device
    /// @param chainID The blockchain ID where the NFT is deployed
    /// @param NFTcontract The contract address in bytes format (must be 20 bytes for Ethereum or 32 bytes for Solana)
    /// @param tokenID The token ID of the NFT
    /// @return isNewDevice True if this is a new device registration, false if updating existing device
    /// @dev Reverts if:
    /// - ioIDIdentifier is zero
    /// - NFTcontract length is not 20 bytes (Ethereum) or 32 bytes (Solana)
    function _setDeviceNFT(
        bytes32 ioIDIdentifier,
        uint256 chainID,
        bytes memory NFTcontract,
        uint256 tokenID
    ) internal virtual returns (bool isNewDevice) {
        require(ioIDIdentifier != bytes32(0), "Invalid ioID identifier");
        require(NFTcontract.length == 20 || NFTcontract.length == 32, "Invalid NFT contract length");

        NFTMappingStorage storage $ = _getNFTMappingStorage();
        
        // Check if this is a new device registration
        isNewDevice = $._ioidNFTMapping[ioIDIdentifier].chainID == 0;
        
        // Set the device NFT data
        $._ioidNFTMapping[ioIDIdentifier] = DeviceNFT(chainID, NFTcontract, tokenID);
        
        emit DeviceNFTUpdated(ioIDIdentifier, chainID, NFTcontract, tokenID);
        
        return isNewDevice;
    }

    /**
     * @notice Internal function to delete a device NFT
     * @param ioIDIdentifier The unique identifier for the device
     * @return wasExisting True if the device existed before deletion
     * @dev Reverts if:
     * - ioIDIdentifier is zero
     */
    function _deleteDeviceNFT(
        bytes32 ioIDIdentifier
    ) internal virtual returns (bool wasExisting) {
        require(ioIDIdentifier != bytes32(0), "Invalid ioID identifier");

        NFTMappingStorage storage $ = _getNFTMappingStorage();
        
        wasExisting = $._ioidNFTMapping[ioIDIdentifier].chainID != 0;
        
        delete $._ioidNFTMapping[ioIDIdentifier];
        
        if (wasExisting) {
            emit DeviceNFTDeleted(ioIDIdentifier);
        }
        
        return wasExisting;
    }

    /// @notice Retrieves the NFT information for a given ioID
    /// @param ioIDIdentifier The unique identifier for the device
    /// @return chainID The blockchain ID where the NFT is deployed
    /// @return NFTcontract The contract address in bytes format
    /// @return tokenID The token ID of the NFT
    function getDeviceNFT(bytes32 ioIDIdentifier) 
        public 
        view virtual
        returns (
            uint256 chainID,
            bytes memory NFTcontract,
            uint256 tokenID
        ) 
    {
        NFTMappingStorage storage $ = _getNFTMappingStorage();
        DeviceNFT memory deviceNFT = $._ioidNFTMapping[ioIDIdentifier];
        return (deviceNFT.chainID, deviceNFT.NFTcontract, deviceNFT.tokenID);
    }
}
