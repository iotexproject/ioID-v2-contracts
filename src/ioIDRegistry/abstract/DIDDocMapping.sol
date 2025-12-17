// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

abstract contract DIDDocMapping {
    struct DIDDocMetadata {
        string didDocUri;
        bytes32 didDocHash;
    }

    /// @custom:storage-location erc7201:diddocmapping.storage
    struct DIDDocMappingStorage {
        mapping(bytes32 => DIDDocMetadata) _didDocMapping;
    }

    // keccak256(abi.encode(uint256(keccak256("diddocmapping.storage")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant DIDDOC_MAPPING_STORAGE_LOCATION = 
        0x5c44c6d81843923dfbfacabeec9ca75ace1e0e41bbc5e9869a46366e9f818b00;

    function _getDIDDocMappingStorage() private pure returns (DIDDocMappingStorage storage $) {
        assembly {
            $.slot := DIDDOC_MAPPING_STORAGE_LOCATION
        }
    }

    event DIDDocMetadataUpdated(
        bytes32 indexed ioIDIdentifier,
        string didDocUri,
        bytes32 didDocHash
    );

    event DIDDocMetadataDeleted(
        bytes32 ioIDIdentifier
    );
    
    /**
     * @dev Internal function to store DID metadata
     * @param ioIDIdentifier The decentralized identifier key
     * @param didDocUri The DID URI string
     * @param didDocHash The content hash of DID document
     * @dev Reverts if:
     * - ioIDIdentifier is zero
     */
    function _setDIDDocMetadata(
        bytes32 ioIDIdentifier,
        string memory didDocUri,
        bytes32 didDocHash
    ) internal virtual {
        require(ioIDIdentifier != bytes32(0), "Invalid ioID identifier");
        
        DIDDocMappingStorage storage $ = _getDIDDocMappingStorage();
        $._didDocMapping[ioIDIdentifier] = DIDDocMetadata(didDocUri, didDocHash);
        emit DIDDocMetadataUpdated(ioIDIdentifier, didDocUri, didDocHash);
    }

    /**
     * @dev Internal function to delete DID metadata
     * @param ioIDIdentifier The decentralized identifier key
     * @dev Reverts if:
     * - ioIDIdentifier is zero
     */
    function _deleteDIDDocMetadata(
        bytes32 ioIDIdentifier
    ) internal virtual {
        require(ioIDIdentifier != bytes32(0), "Invalid ioID identifier");
        
        DIDDocMappingStorage storage $ = _getDIDDocMappingStorage();
        DIDDocMetadata memory meta = $._didDocMapping[ioIDIdentifier];
        bool wasExisting = bytes(meta.didDocUri).length > 0;
        delete $._didDocMapping[ioIDIdentifier];
        if (wasExisting) {
            emit DIDDocMetadataDeleted(ioIDIdentifier);
        }
    }

     /**
     * @notice Get full DID metadata for an identifier
     * @param ioIDIdentifier The decentralized identifier key
     * @return didDocUri The DID URI string
     * @return didDocHash The content hash of DID document
     * @dev Returns empty values if identifier doesn't exist
     */
    function getDIDDocMetadata(bytes32 ioIDIdentifier) public view virtual returns (string memory didDocUri, bytes32 didDocHash) {
        DIDDocMappingStorage storage $ = _getDIDDocMappingStorage();
        didDocUri = $._didDocMapping[ioIDIdentifier].didDocUri;
        didDocHash = $._didDocMapping[ioIDIdentifier].didDocHash;
        return (didDocUri, didDocHash);
    }
} 