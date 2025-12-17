// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/ioIDRegistry/ioIDRegistry.sol";
import "./mock/IoIDRegistryV2.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract IoIDRegistryTest is Test {
    IoIDRegistry public registry;
    IoIDRegistryV2 public registryV2;
    ERC1967Proxy public proxy;
    
    address public owner;
    address public nonOwner;
    address public operator1;
    
    // Test data
    bytes32 public constant TEST_IOID = keccak256("test-device-1");
    uint256 public constant TEST_CHAIN_ID = 1;
    bytes public constant TEST_NFT_CONTRACT = abi.encodePacked(address(0x1234567890123456789012345678901234567890));
    uint256 public constant TEST_TOKEN_ID = 1;
    string public constant TEST_DESCRIPTION = "Test Device Description";
    string public constant TEST_DID_URI = "did:example:123456789abcdefghi";
    bytes32 public constant TEST_DID_HASH = keccak256("test-did-document");
    
    event DeviceNFTUpdated(bytes32 indexed ioIDIdentifier, uint256 chainID, bytes NFTcontract, uint256 tokenID);
    event DeviceDescriptionUpdated(bytes32 indexed ioIDIdentifier, string description);
    event DIDDocMetadataUpdated(bytes32 indexed ioIDIdentifier, string didDocUri, bytes32 didDocHash);
    
    event DeviceNFTDeleted(bytes32 ioIDIdentifier);
    event DIDDocMetadataDeleted(bytes32 ioIDIdentifier);
    
    function setUp() public {
        owner = address(this);
        nonOwner = address(0x1);
        operator1 = address(0x2);
        
        // Deploy implementation
        registry = new IoIDRegistry();
        
        // Deploy proxy and initialize
        bytes memory initData = abi.encodeWithSelector(
            IoIDRegistry.initialize.selector,
            owner
        );
        proxy = new ERC1967Proxy(address(registry), initData);
        
        // Wrap proxy in IoIDRegistry interface
        registry = IoIDRegistry(address(proxy));
    }
    
    function testInitialization() public {
        assertEq(registry.owner(), owner);
        // Check that owner is initially set as operator
        assertEq(registry.operator(), owner);
        assertEq(registry.totalDevices(), 0);
    }
    
    function testBasicFunctionality() public {
        // Test registering a device NFT
        vm.expectEmit(true, false, false, true);
        emit DeviceNFTUpdated(TEST_IOID, TEST_CHAIN_ID, TEST_NFT_CONTRACT, TEST_TOKEN_ID);
        
        registry.registerDeviceNFT(TEST_IOID, TEST_CHAIN_ID, TEST_NFT_CONTRACT, TEST_TOKEN_ID);
        
        // Verify the device was registered
        (uint256 chainID, bytes memory nftContract, uint256 tokenID) = registry.getDeviceNFT(TEST_IOID);
        assertEq(chainID, TEST_CHAIN_ID);
        assertEq(nftContract, TEST_NFT_CONTRACT);
        assertEq(tokenID, TEST_TOKEN_ID);
        assertEq(registry.totalDevices(), 1);
 
        // Test deletion
        vm.expectEmit(true, false, false, true);
        emit DeviceNFTDeleted(TEST_IOID);
        registry.deleteDeviceNFT(TEST_IOID);
 
        // Verify deletion
        (chainID, nftContract, tokenID) = registry.getDeviceNFT(TEST_IOID);
        assertEq(chainID, 0);
        assertEq(nftContract.length, 0);
        assertEq(tokenID, 0);
        assertEq(registry.totalDevices(), 0);
    }
    
    function testUpgradeability() public {
        // First, register a device with the original contract
        registry.registerDeviceNFTWithDIDDoc(TEST_IOID, TEST_CHAIN_ID, TEST_NFT_CONTRACT, TEST_TOKEN_ID, TEST_DID_URI, TEST_DID_HASH);
        
        // Verify data exists in V1
        (uint256 chainID, bytes memory nftContract, uint256 tokenID) = registry.getDeviceNFT(TEST_IOID);
        assertEq(chainID, TEST_CHAIN_ID);
        assertEq(nftContract, TEST_NFT_CONTRACT);
        assertEq(tokenID, TEST_TOKEN_ID);
        
        // Add verification for DID in V1
        (string memory didUri, bytes32 didHash) = registry.getDIDDocMetadata(TEST_IOID);
        assertEq(didUri, TEST_DID_URI);
        assertEq(didHash, TEST_DID_HASH);
        
        // Register a device with chainID=0 before upgrade (V1 allows this)
        bytes32 zeroChainIoID = keccak256("zero-chain-device");
        registry.registerDeviceNFT(zeroChainIoID, 0, TEST_NFT_CONTRACT, TEST_TOKEN_ID + 2);
        
        // Verify it was registered in V1
        (uint256 zeroChainID, , uint256 zeroTokenID) = registry.getDeviceNFT(zeroChainIoID);
        assertEq(zeroChainID, 0);
        assertEq(zeroTokenID, TEST_TOKEN_ID + 2);
        
        // Deploy V2 implementation
        registryV2 = new IoIDRegistryV2();
        
        // Upgrade to V2
        registry.upgradeToAndCall(address(registryV2), "");
        
        // Wrap proxy in IoIDRegistryV2 interface
        IoIDRegistryV2 registryV2Proxy = IoIDRegistryV2(address(proxy));
        
        // Verify old data is preserved after upgrade
        (chainID, nftContract, tokenID) = registryV2Proxy.getDeviceNFT(TEST_IOID);
        assertEq(chainID, TEST_CHAIN_ID);
        assertEq(nftContract, TEST_NFT_CONTRACT);
        assertEq(tokenID, TEST_TOKEN_ID);
        
        // Add verification for DID, totalDevices, and operator after upgrade
        (didUri, didHash) = registryV2Proxy.getDIDDocMetadata(TEST_IOID);
        assertEq(didUri, TEST_DID_URI);
        assertEq(didHash, TEST_DID_HASH);
        assertEq(registryV2Proxy.totalDevices(), 2); // Original device + zero-chain device
        assertEq(registryV2Proxy.operator(), owner);
        
        // Verify the previously registered zero chainID device is still preserved
        (zeroChainID, , zeroTokenID) = registryV2Proxy.getDeviceNFT(zeroChainIoID);
        assertEq(zeroChainID, 0);
        assertEq(zeroTokenID, TEST_TOKEN_ID + 2);
        
        // Test new functionality
        assertEq(registryV2Proxy.version(), "2.0.0");
        
        // Test new function - set device description
        vm.expectEmit(true, false, false, true);
        emit DeviceDescriptionUpdated(TEST_IOID, TEST_DESCRIPTION);
        
        registryV2Proxy.setDeviceDescription(TEST_IOID, TEST_DESCRIPTION);
        
        // Verify description was set
        assertEq(registryV2Proxy.getDeviceDescription(TEST_IOID), TEST_DESCRIPTION);
        
        // Test new combined function
        bytes32 newIoID = keccak256("test-device-2");
        string memory newDescription = "New Device Description";
        
        vm.expectEmit(true, false, false, true);
        emit DeviceNFTUpdated(newIoID, TEST_CHAIN_ID, TEST_NFT_CONTRACT, TEST_TOKEN_ID + 1);
        vm.expectEmit(true, false, false, true);
        emit DeviceDescriptionUpdated(newIoID, newDescription);
        
        registryV2Proxy.registerDeviceNFTWithDescription(
            newIoID,
            TEST_CHAIN_ID,
            TEST_NFT_CONTRACT,
            TEST_TOKEN_ID + 1,
            newDescription
        );
        
        // Verify both NFT and description were set
        (chainID, nftContract, tokenID) = registryV2Proxy.getDeviceNFT(newIoID);
        assertEq(chainID, TEST_CHAIN_ID);
        assertEq(nftContract, TEST_NFT_CONTRACT);
        assertEq(tokenID, TEST_TOKEN_ID + 1);
        assertEq(registryV2Proxy.getDeviceDescription(newIoID), newDescription);
        
        // Test that V2 now rejects chainID=0 (new validation logic)
        bytes32 newZeroChainIoID = keccak256("new-zero-chain-device");
        vm.expectRevert("Chain ID cannot be zero");
        registryV2Proxy.registerDeviceNFT(newZeroChainIoID, 0, TEST_NFT_CONTRACT, TEST_TOKEN_ID + 3);

        // Check final totalDevices count
        assertEq(registryV2Proxy.totalDevices(), 3); // Original + zero-chain + new with description

        // Test new variable
        assertEq(registryV2Proxy.newVar(), 0); // Initially zero
        registryV2Proxy.setNewVar(42);
        assertEq(registryV2Proxy.newVar(), 42);

        // Non-owner cannot set
        vm.prank(nonOwner);
        vm.expectRevert();
        registryV2Proxy.setNewVar(100);
    }
    
    function testOnlyOwnerCanUpgrade() public {
        registryV2 = new IoIDRegistryV2();
        
        // Try to upgrade from non-owner account
        vm.prank(nonOwner);
        vm.expectRevert();
        registry.upgradeToAndCall(address(registryV2), "");
    }
    
    function testUpgradePreservesOwnership() public {
        // Deploy V2 implementation
        registryV2 = new IoIDRegistryV2();
        
        // Upgrade to V2
        registry.upgradeToAndCall(address(registryV2), "");
        
        // Verify owner is preserved
        IoIDRegistryV2 registryV2Proxy = IoIDRegistryV2(address(proxy));
        assertEq(registryV2Proxy.owner(), owner);
        assertEq(registryV2Proxy.operator(), owner);
    }
    
    function testOnlyOwnerCanDelete() public {
        registry.registerDeviceNFT(TEST_IOID, TEST_CHAIN_ID, TEST_NFT_CONTRACT, TEST_TOKEN_ID);
        assertEq(registry.totalDevices(), 1);
 
        // Set different operator
        registry.setOperator(operator1);
 
        // Operator cannot delete
        vm.prank(operator1);
        vm.expectRevert();
        registry.deleteDeviceNFT(TEST_IOID);
 
        // Owner can delete
        registry.deleteDeviceNFT(TEST_IOID);
        assertEq(registry.totalDevices(), 0);
    }
    
    function testV2OnlyOwnerFunctions() public {
        // Deploy and upgrade to V2
        registryV2 = new IoIDRegistryV2();
        registry.upgradeToAndCall(address(registryV2), "");
        IoIDRegistryV2 registryV2Proxy = IoIDRegistryV2(address(proxy));
        
        // Test that non-owner cannot call new functions
        vm.prank(nonOwner);
        vm.expectRevert();
        registryV2Proxy.setDeviceDescription(TEST_IOID, TEST_DESCRIPTION);
        
        vm.prank(nonOwner);
        vm.expectRevert();
        registryV2Proxy.registerDeviceNFTWithDescription(
            TEST_IOID,
            TEST_CHAIN_ID,
            TEST_NFT_CONTRACT,
            TEST_TOKEN_ID,
            TEST_DESCRIPTION
        );
    }
    
    function testMultipleUpgrades() public {
        // Register initial data
        registry.registerDeviceNFT(TEST_IOID, TEST_CHAIN_ID, TEST_NFT_CONTRACT, TEST_TOKEN_ID);
        
        // First upgrade to V2
        registryV2 = new IoIDRegistryV2();
        registry.upgradeToAndCall(address(registryV2), "");
        IoIDRegistryV2 registryV2Proxy = IoIDRegistryV2(address(proxy));
        
        // Add description in V2
        registryV2Proxy.setDeviceDescription(TEST_IOID, TEST_DESCRIPTION);
        
        // Deploy another V2 implementation (simulating another upgrade)
        IoIDRegistryV2 registryV2New = new IoIDRegistryV2();
        registryV2Proxy.upgradeToAndCall(address(registryV2New), "");
        
        // Verify all data is preserved
        (uint256 chainID, bytes memory nftContract, uint256 tokenID) = registryV2Proxy.getDeviceNFT(TEST_IOID);
        assertEq(chainID, TEST_CHAIN_ID);
        assertEq(nftContract, TEST_NFT_CONTRACT);
        assertEq(tokenID, TEST_TOKEN_ID);
        assertEq(registryV2Proxy.getDeviceDescription(TEST_IOID), TEST_DESCRIPTION);
    }
    
    function testUpgradeFailsWithInvalidImplementation() public {
        // Try to upgrade to an invalid address
        vm.expectRevert();
        registry.upgradeToAndCall(address(0), "");
    }
    
    // ============ COMPREHENSIVE FUNCTIONALITY TESTS ============
    
    function testRegisterDeviceNFTWithDIDDoc() public {
        // Test the combined function that registers both NFT and DID metadata
        vm.expectEmit(true, false, false, true);
        emit DeviceNFTUpdated(TEST_IOID, TEST_CHAIN_ID, TEST_NFT_CONTRACT, TEST_TOKEN_ID);
        vm.expectEmit(true, false, false, true);
        emit DIDDocMetadataUpdated(TEST_IOID, TEST_DID_URI, TEST_DID_HASH);
        
        registry.registerDeviceNFTWithDIDDoc(
            TEST_IOID,
            TEST_CHAIN_ID,
            TEST_NFT_CONTRACT,
            TEST_TOKEN_ID,
            TEST_DID_URI,
            TEST_DID_HASH
        );
        
        // Verify NFT data
        (uint256 chainID, bytes memory nftContract, uint256 tokenID) = registry.getDeviceNFT(TEST_IOID);
        assertEq(chainID, TEST_CHAIN_ID);
        assertEq(nftContract, TEST_NFT_CONTRACT);
        assertEq(tokenID, TEST_TOKEN_ID);
        
        // Verify DID data
        (string memory didUri, bytes32 didHash) = registry.getDIDDocMetadata(TEST_IOID);
        assertEq(didUri, TEST_DID_URI);
        assertEq(didHash, TEST_DID_HASH);
        assertEq(registry.totalDevices(), 1);
 
        // Test deletion with DID
        vm.expectEmit(true, false, false, true);
        emit DeviceNFTDeleted(TEST_IOID);
        vm.expectEmit(true, false, false, true);
        emit DIDDocMetadataDeleted(TEST_IOID);
        registry.deleteDeviceNFT(TEST_IOID);
 
        // Verify deletion
        (chainID, nftContract, tokenID) = registry.getDeviceNFT(TEST_IOID);
        assertEq(chainID, 0);
        assertEq(nftContract.length, 0);
        assertEq(tokenID, 0);
        (didUri, didHash) = registry.getDIDDocMetadata(TEST_IOID);
        assertEq(didUri, "");
        assertEq(didHash, bytes32(0));
        assertEq(registry.totalDevices(), 0);
    }
    
    function testGetDIDDocMetadata() public {
        // Test getting DID metadata for non-existent identifier (should return empty values)
        (string memory didUri, bytes32 didHash) = registry.getDIDDocMetadata(TEST_IOID);
        assertEq(didUri, "");
        assertEq(didHash, bytes32(0));
        
        // Register DID metadata and test retrieval
        registry.registerDeviceNFTWithDIDDoc(
            TEST_IOID,
            TEST_CHAIN_ID,
            TEST_NFT_CONTRACT,
            TEST_TOKEN_ID,
            TEST_DID_URI,
            TEST_DID_HASH
        );
        
        (didUri, didHash) = registry.getDIDDocMetadata(TEST_IOID);
        assertEq(didUri, TEST_DID_URI);
        assertEq(didHash, TEST_DID_HASH);
    }
    
    function testGetDeviceNFTForNonExistentIdentifier() public {
        // Test getting NFT data for non-existent identifier (should return zero values)
        (uint256 chainID, bytes memory nftContract, uint256 tokenID) = registry.getDeviceNFT(TEST_IOID);
        assertEq(chainID, 0);
        assertEq(nftContract.length, 0);
        assertEq(tokenID, 0);
    }
    
    // ============ ERROR CASES ============
    
    function testRegisterDeviceNFTWithZeroIdentifier() public {
        vm.expectRevert("Invalid ioID identifier");
        registry.registerDeviceNFT(bytes32(0), TEST_CHAIN_ID, TEST_NFT_CONTRACT, TEST_TOKEN_ID);
    }
    
    function testRegisterDeviceNFTWithInvalidContractLength() public {
        // Test with contract address that's neither 20 nor 32 bytes
        bytes memory invalidContract = abi.encodePacked(uint256(0x123));  // 32 bytes but invalid
        invalidContract = abi.encodePacked(uint128(0x123));  // 16 bytes - invalid
        
        vm.expectRevert("Invalid NFT contract length");
        registry.registerDeviceNFT(TEST_IOID, TEST_CHAIN_ID, invalidContract, TEST_TOKEN_ID);
    }
    
    function testRegisterDeviceNFTWith20ByteContract() public {
        // Test with valid Ethereum address (20 bytes)
        bytes memory ethereumContract = abi.encodePacked(address(0x1234567890123456789012345678901234567890));
        
        vm.expectEmit(true, false, false, true);
        emit DeviceNFTUpdated(TEST_IOID, TEST_CHAIN_ID, ethereumContract, TEST_TOKEN_ID);
        
        registry.registerDeviceNFT(TEST_IOID, TEST_CHAIN_ID, ethereumContract, TEST_TOKEN_ID);
        
        (uint256 chainID, bytes memory nftContract, uint256 tokenID) = registry.getDeviceNFT(TEST_IOID);
        assertEq(chainID, TEST_CHAIN_ID);
        assertEq(nftContract, ethereumContract);
        assertEq(tokenID, TEST_TOKEN_ID);
    }
    
    function testRegisterDeviceNFTWith32ByteContract() public {
        // Test with valid Solana address (32 bytes)
        bytes memory solanaContract = abi.encodePacked(bytes32(keccak256("solana-contract-address")));
        
        vm.expectEmit(true, false, false, true);
        emit DeviceNFTUpdated(TEST_IOID, TEST_CHAIN_ID, solanaContract, TEST_TOKEN_ID);
        
        registry.registerDeviceNFT(TEST_IOID, TEST_CHAIN_ID, solanaContract, TEST_TOKEN_ID);
        
        (uint256 chainID, bytes memory nftContract, uint256 tokenID) = registry.getDeviceNFT(TEST_IOID);
        assertEq(chainID, TEST_CHAIN_ID);
        assertEq(nftContract, solanaContract);
        assertEq(tokenID, TEST_TOKEN_ID);
    }
    
    function testRegisterDeviceNFTWithDIDDocErrorCases() public {
        // Test with zero identifier
        vm.expectRevert("Invalid ioID identifier");
        registry.registerDeviceNFTWithDIDDoc(
            bytes32(0),
            TEST_CHAIN_ID,
            TEST_NFT_CONTRACT,
            TEST_TOKEN_ID,
            TEST_DID_URI,
            TEST_DID_HASH
        );
        
        // Test with invalid contract length
        bytes memory invalidContract = abi.encodePacked(uint128(0x123));  // 16 bytes
        vm.expectRevert("Invalid NFT contract length");
        registry.registerDeviceNFTWithDIDDoc(
            TEST_IOID,
            TEST_CHAIN_ID,
            invalidContract,
            TEST_TOKEN_ID,
            TEST_DID_URI,
            TEST_DID_HASH
        );
    }
    
    // ============ ACCESS CONTROL TESTS ============
    
    function testOnlyOperatorCanRegisterDeviceNFT() public {
        // Non-operator should not be able to register
        vm.prank(nonOwner);
        vm.expectRevert("Not operator");
        registry.registerDeviceNFT(TEST_IOID, TEST_CHAIN_ID, TEST_NFT_CONTRACT, TEST_TOKEN_ID);
        
        // Owner (who is initially the operator) should be able to register
        registry.registerDeviceNFT(TEST_IOID, TEST_CHAIN_ID, TEST_NFT_CONTRACT, TEST_TOKEN_ID);
        
        // Set a new operator
        registry.setOperator(operator1);
        
        // New operator should be able to register
        vm.prank(operator1);
        bytes32 newIoID = keccak256("operator-device");
        registry.registerDeviceNFT(newIoID, TEST_CHAIN_ID, TEST_NFT_CONTRACT, TEST_TOKEN_ID + 1);
        
        // Owner should no longer be able to register (no longer operator)
        vm.expectRevert("Not operator");
        registry.registerDeviceNFT(keccak256("owner-device"), TEST_CHAIN_ID, TEST_NFT_CONTRACT, TEST_TOKEN_ID + 2);
    }
    
    function testOnlyOperatorCanRegisterDeviceNFTWithDIDDoc() public {
        // Non-operator should not be able to register
        vm.prank(nonOwner);
        vm.expectRevert("Not operator");
        registry.registerDeviceNFTWithDIDDoc(
            TEST_IOID,
            TEST_CHAIN_ID,
            TEST_NFT_CONTRACT,
            TEST_TOKEN_ID,
            TEST_DID_URI,
            TEST_DID_HASH
        );
        
        // Set operator to operator1
        registry.setOperator(operator1);
        
        // New operator should be able to register
        vm.prank(operator1);
        registry.registerDeviceNFTWithDIDDoc(
            TEST_IOID,
            TEST_CHAIN_ID,
            TEST_NFT_CONTRACT,
            TEST_TOKEN_ID,
            TEST_DID_URI,
            TEST_DID_HASH
        );
    }
    
    // ============ OPERATOR MANAGEMENT TESTS ============
    
    function testSetOperator() public {
        // Initially, owner should be the operator
        assertEq(registry.operator(), owner);
        
        // Owner should be able to set a new operator
        registry.setOperator(operator1);
        
        // Operator should now be operator1
        assertEq(registry.operator(), operator1);
        
        // operator1 should be able to register devices
        vm.prank(operator1);
        registry.registerDeviceNFT(TEST_IOID, TEST_CHAIN_ID, TEST_NFT_CONTRACT, TEST_TOKEN_ID);
        
        // Verify the device was registered
        (uint256 chainID, bytes memory nftContract, uint256 tokenID) = registry.getDeviceNFT(TEST_IOID);
        assertEq(chainID, TEST_CHAIN_ID);
        assertEq(nftContract, TEST_NFT_CONTRACT);
        assertEq(tokenID, TEST_TOKEN_ID);
    }
    
    function testOnlyOwnerCanSetOperator() public {
        // Non-owner should not be able to set operator
        vm.prank(nonOwner);
        vm.expectRevert();
        registry.setOperator(operator1);
        
        // Owner should be able to set operator
        registry.setOperator(operator1);
        assertEq(registry.operator(), operator1);
        
        // New operator cannot set another operator (only owner can)
        vm.prank(operator1);
        vm.expectRevert();
        registry.setOperator(nonOwner);
        
        // Non-owner still cannot set operator even after operator change
        vm.prank(nonOwner);
        vm.expectRevert();
        registry.setOperator(owner);
    }
    
    function testSetOperatorToZeroAddressReverts() public {
        vm.expectRevert("Operator cannot be zero address");
        registry.setOperator(address(0));
    }
    
    function testOperatorChange() public {
        // Set operator to operator1
        registry.setOperator(operator1);
        
        // operator1 should be able to register
        vm.prank(operator1);
        bytes32 device1 = keccak256("device-1");
        registry.registerDeviceNFT(device1, TEST_CHAIN_ID, TEST_NFT_CONTRACT, 1);
        
        // Change operator back to owner
        registry.setOperator(owner);
        
        // operator1 should no longer be able to register
        vm.prank(operator1);
        vm.expectRevert("Not operator");
        registry.registerDeviceNFT(keccak256("device-2"), TEST_CHAIN_ID, TEST_NFT_CONTRACT, 2);
        
        // Owner should now be able to register again
        bytes32 device2 = keccak256("device-2");
        registry.registerDeviceNFT(device2, TEST_CHAIN_ID, TEST_NFT_CONTRACT, 2);
        
        // Verify both devices were registered
        (uint256 chainID1, , uint256 tokenID1) = registry.getDeviceNFT(device1);
        assertEq(chainID1, TEST_CHAIN_ID);
        assertEq(tokenID1, 1);
        
        (uint256 chainID2, , uint256 tokenID2) = registry.getDeviceNFT(device2);
        assertEq(chainID2, TEST_CHAIN_ID);
        assertEq(tokenID2, 2);
    }
    
    function testOperatorPersistsAfterOwnershipTransfer() public {
        // Set operator to operator1
        registry.setOperator(operator1);
        assertEq(registry.operator(), operator1);
        
        // Transfer ownership
        address newOwner = address(0x3);
        registry.transferOwnership(newOwner);
        vm.prank(newOwner);
        registry.acceptOwnership();
        
        // Operator should still be operator1
        assertEq(registry.operator(), operator1);
        
        // operator1 should still be able to register
        vm.prank(operator1);
        registry.registerDeviceNFT(TEST_IOID, TEST_CHAIN_ID, TEST_NFT_CONTRACT, TEST_TOKEN_ID);
        
        // New owner should be able to change operator
        vm.prank(newOwner);
        registry.setOperator(newOwner);
        assertEq(registry.operator(), newOwner);
        
        // Old operator should no longer work
        vm.prank(operator1);
        vm.expectRevert("Not operator");
        registry.registerDeviceNFT(keccak256("new-device"), TEST_CHAIN_ID, TEST_NFT_CONTRACT, TEST_TOKEN_ID + 1);
    }
    
    // ============ OWNERSHIP TRANSFER TESTS ============
    
    function testOwnershipTransferProcess() public {
        address newOwner = address(0x4); // Use different address than operator1
        
        // Current owner should be able to start transfer
        registry.transferOwnership(newOwner);
        
        // Pending owner should be set
        assertEq(registry.pendingOwner(), newOwner);
        assertEq(registry.owner(), owner); // Owner shouldn't change yet
        
        // Operator should still be the old owner
        assertEq(registry.operator(), owner);
        
        // New owner should be able to accept ownership
        vm.prank(newOwner);
        registry.acceptOwnership();
        
        // Ownership should be transferred
        assertEq(registry.owner(), newOwner);
        assertEq(registry.pendingOwner(), address(0));
        
        // Operator should still be the old owner (operator role persists)
        assertEq(registry.operator(), owner);
        
        // Old owner should still be able to register devices (still operator)
        registry.registerDeviceNFT(TEST_IOID, TEST_CHAIN_ID, TEST_NFT_CONTRACT, TEST_TOKEN_ID);
        
        // New owner should be able to change operator
        vm.prank(newOwner);
        registry.setOperator(newOwner);
        
        // Old owner should no longer be able to register
        vm.expectRevert("Not operator");
        registry.registerDeviceNFT(keccak256("another-device"), TEST_CHAIN_ID, TEST_NFT_CONTRACT, TEST_TOKEN_ID + 1);
        
        // New owner should be able to register (now the operator)
        vm.prank(newOwner);
        registry.registerDeviceNFT(keccak256("another-device"), TEST_CHAIN_ID, TEST_NFT_CONTRACT, TEST_TOKEN_ID + 1);
    }
    
    function testRenounceOwnership() public {
        // Set a different operator first (so old owner isn't operator)
        registry.setOperator(operator1);
        
        // Owner should be able to renounce ownership
        registry.renounceOwnership();
        
        // Owner should be zero address
        assertEq(registry.owner(), address(0));
        
        // Operator should still be operator1 (operator role persists)
        assertEq(registry.operator(), operator1);
        
        // operator1 should still be able to register devices
        vm.prank(operator1);
        registry.registerDeviceNFT(TEST_IOID, TEST_CHAIN_ID, TEST_NFT_CONTRACT, TEST_TOKEN_ID);
        
        // No one should be able to set a new operator (no owner)
        vm.prank(operator1);
        vm.expectRevert();
        registry.setOperator(nonOwner);
        
        // No one should be able to upgrade (no owner)
        IoIDRegistryV2 newImpl = new IoIDRegistryV2();
        vm.prank(operator1);
        vm.expectRevert();
        registry.upgradeToAndCall(address(newImpl), "");
    }
    
    // ============ DATA OVERWRITE TESTS ============
    
    function testOverwriteDeviceNFT() public {
        // Register initial NFT
        registry.registerDeviceNFT(TEST_IOID, TEST_CHAIN_ID, TEST_NFT_CONTRACT, TEST_TOKEN_ID);
        
        // Verify initial registration
        (uint256 chainID, bytes memory nftContract, uint256 tokenID) = registry.getDeviceNFT(TEST_IOID);
        assertEq(chainID, TEST_CHAIN_ID);
        assertEq(tokenID, TEST_TOKEN_ID);
        
        // Register new NFT with same identifier (should overwrite)
        uint256 newChainID = 137; // Polygon
        uint256 newTokenID = 999;
        
        vm.expectEmit(true, false, false, true);
        emit DeviceNFTUpdated(TEST_IOID, newChainID, TEST_NFT_CONTRACT, newTokenID);
        
        registry.registerDeviceNFT(TEST_IOID, newChainID, TEST_NFT_CONTRACT, newTokenID);
        
        // Verify overwrite
        (chainID, nftContract, tokenID) = registry.getDeviceNFT(TEST_IOID);
        assertEq(chainID, newChainID);
        assertEq(tokenID, newTokenID);
    }
    
    function testOverwriteDIDMetadata() public {
        // Register initial DID metadata
        registry.registerDeviceNFTWithDIDDoc(
            TEST_IOID,
            TEST_CHAIN_ID,
            TEST_NFT_CONTRACT,
            TEST_TOKEN_ID,
            TEST_DID_URI,
            TEST_DID_HASH
        );
        
        // Verify initial registration
        (string memory didUri, bytes32 didHash) = registry.getDIDDocMetadata(TEST_IOID);
        assertEq(didUri, TEST_DID_URI);
        assertEq(didHash, TEST_DID_HASH);
        
        // Register new DID metadata with same identifier (should overwrite)
        string memory newDIDUri = "did:example:new-identifier";
        bytes32 newDIDHash = keccak256("new-did-document");
        
        vm.expectEmit(true, false, false, true);
        emit DIDDocMetadataUpdated(TEST_IOID, newDIDUri, newDIDHash);
        
        registry.registerDeviceNFTWithDIDDoc(
            TEST_IOID,
            TEST_CHAIN_ID,
            TEST_NFT_CONTRACT,
            TEST_TOKEN_ID,
            newDIDUri,
            newDIDHash
        );
        
        // Verify overwrite
        (didUri, didHash) = registry.getDIDDocMetadata(TEST_IOID);
        assertEq(didUri, newDIDUri);
        assertEq(didHash, newDIDHash);
    }
    
    // ============ MULTIPLE DEVICES TESTS ============
    
    function testMultipleDeviceRegistrations() public {
        bytes32 device1 = keccak256("device-1");
        bytes32 device2 = keccak256("device-2");
        bytes32 device3 = keccak256("device-3");
        
        // Register multiple devices
        registry.registerDeviceNFT(device1, 1, TEST_NFT_CONTRACT, 1);
        registry.registerDeviceNFT(device2, 137, TEST_NFT_CONTRACT, 2);
        registry.registerDeviceNFTWithDIDDoc(device3, 56, TEST_NFT_CONTRACT, 3, TEST_DID_URI, TEST_DID_HASH);
        
                // Verify all devices are stored correctly
        (uint256 chainID, , uint256 tokenID) = registry.getDeviceNFT(device1);
        assertEq(chainID, 1);
        assertEq(tokenID, 1);
        
        (chainID, , tokenID) = registry.getDeviceNFT(device2);
        assertEq(chainID, 137);
        assertEq(tokenID, 2);
        
        (chainID, , tokenID) = registry.getDeviceNFT(device3);
        assertEq(chainID, 56);
        assertEq(tokenID, 3);
        
        // Verify DID metadata only exists for device3
        (string memory didUri, bytes32 didHash) = registry.getDIDDocMetadata(device1);
        assertEq(didUri, "");
        assertEq(didHash, bytes32(0));
        
        (didUri, didHash) = registry.getDIDDocMetadata(device3);
        assertEq(didUri, TEST_DID_URI);
        assertEq(didHash, TEST_DID_HASH);
        assertEq(registry.totalDevices(), 3);

        // Delete one device
        registry.deleteDeviceNFT(device2);
        assertEq(registry.totalDevices(), 2);

        // Verify device2 is deleted
        (chainID, , tokenID) = registry.getDeviceNFT(device2);
        assertEq(chainID, 0);
        assertEq(tokenID, 0);

        // Other devices still exist
        (chainID, , tokenID) = registry.getDeviceNFT(device1);
        assertEq(chainID, 1);
        assertEq(tokenID, 1);

        (chainID, , tokenID) = registry.getDeviceNFT(device3);
        assertEq(chainID, 56);
        assertEq(tokenID, 3);
    }

    function testDeleteNonExistentDevice() public {
        assertEq(registry.totalDevices(), 0);
 
        // Delete non-existent shouldn't revert but no event and no decrement
        registry.deleteDeviceNFT(TEST_IOID);
        assertEq(registry.totalDevices(), 0);
 
        // Register and delete
        registry.registerDeviceNFT(TEST_IOID, TEST_CHAIN_ID, TEST_NFT_CONTRACT, TEST_TOKEN_ID);
        assertEq(registry.totalDevices(), 1);
        registry.deleteDeviceNFT(TEST_IOID);
        assertEq(registry.totalDevices(), 0);
 
        // Delete again shouldn't decrement below zero
        registry.deleteDeviceNFT(TEST_IOID);
        assertEq(registry.totalDevices(), 0);
    }
} 