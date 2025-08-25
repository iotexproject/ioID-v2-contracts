// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/deviceNFT/DeviceNFTFactory.sol";
import "../src/deviceNFT/DeviceNFTTemplate.sol";

contract DeviceNFTFactoryTest is Test {
    DeviceNFTFactory public factory;
    DeviceNFTTemplate public implementation;
    
    address public deployer = makeAddr("deployer");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    address public operator1 = makeAddr("operator1");
    address public operator2 = makeAddr("operator2");
    
    string public constant NAME1 = "Device NFT Collection 1";
    string public constant SYMBOL1 = "DNFT1";
    string public constant NAME2 = "Device NFT Collection 2";
    string public constant SYMBOL2 = "DNFT2";
    
    function setUp() public {
        // Deploy implementation contract
        implementation = new DeviceNFTTemplate();
        
        // Deploy factory with implementation address
        vm.prank(deployer);
        factory = new DeviceNFTFactory(address(implementation));
    }
    
    function test_Constructor() public {
        assertEq(factory.IMPLEMENTATION(), address(implementation));
    }
    
    function test_ConstructorWithZeroAddress() public {
        vm.prank(deployer);
        DeviceNFTFactory newFactory = new DeviceNFTFactory(address(0));
        assertEq(newFactory.IMPLEMENTATION(), address(0));
    }
    
    function test_CreateDeviceNFT() public {
        vm.prank(user1);
        address cloneAddress = factory.createDeviceNFT(NAME1, SYMBOL1, operator1);
        
        // Verify clone was created
        assertTrue(cloneAddress != address(0));
        assertTrue(cloneAddress != address(implementation));
        
        // Verify clone is properly initialized
        DeviceNFTTemplate clone = DeviceNFTTemplate(cloneAddress);
        assertEq(clone.name(), NAME1);
        assertEq(clone.symbol(), SYMBOL1);
        assertEq(clone.owner(), user1);
        assertEq(clone.operator(), operator1);
    }
    
    function test_CreateMultipleDeviceNFTs() public {
        // Create first device NFT
        vm.prank(user1);
        address clone1 = factory.createDeviceNFT(NAME1, SYMBOL1, operator1);
        
        // Create second device NFT
        vm.prank(user2);
        address clone2 = factory.createDeviceNFT(NAME2, SYMBOL2, operator2);
        
        // Verify both clones are different
        assertTrue(clone1 != clone2);
        assertTrue(clone1 != address(0));
        assertTrue(clone2 != address(0));
        
        // Verify first clone
        DeviceNFTTemplate deviceNFT1 = DeviceNFTTemplate(clone1);
        assertEq(deviceNFT1.name(), NAME1);
        assertEq(deviceNFT1.symbol(), SYMBOL1);
        assertEq(deviceNFT1.owner(), user1);
        assertEq(deviceNFT1.operator(), operator1);
        
        // Verify second clone
        DeviceNFTTemplate deviceNFT2 = DeviceNFTTemplate(clone2);
        assertEq(deviceNFT2.name(), NAME2);
        assertEq(deviceNFT2.symbol(), SYMBOL2);
        assertEq(deviceNFT2.owner(), user2);
        assertEq(deviceNFT2.operator(), operator2);
    }
    
    function test_CreateDeviceNFTWithSameParameters() public {
        // Create first device NFT
        vm.prank(user1);
        address clone1 = factory.createDeviceNFT(NAME1, SYMBOL1, operator1);
        
        // Create second device NFT with same parameters but different sender
        vm.prank(user2);
        address clone2 = factory.createDeviceNFT(NAME1, SYMBOL1, operator1);
        
        // Clones should be different addresses
        assertTrue(clone1 != clone2);
        
        // But should have same name/symbol, different owners
        DeviceNFTTemplate deviceNFT1 = DeviceNFTTemplate(clone1);
        DeviceNFTTemplate deviceNFT2 = DeviceNFTTemplate(clone2);
        
        assertEq(deviceNFT1.name(), deviceNFT2.name());
        assertEq(deviceNFT1.symbol(), deviceNFT2.symbol());
        assertEq(deviceNFT1.operator(), deviceNFT2.operator());
        assertTrue(deviceNFT1.owner() != deviceNFT2.owner());
        assertEq(deviceNFT1.owner(), user1);
        assertEq(deviceNFT2.owner(), user2);
    }
    
    function test_CreateDeviceNFTWithEmptyStrings() public {
        vm.prank(user1);
        address clone = factory.createDeviceNFT("", "", operator1);
        
        DeviceNFTTemplate deviceNFT = DeviceNFTTemplate(clone);
        assertEq(deviceNFT.name(), "");
        assertEq(deviceNFT.symbol(), "");
        assertEq(deviceNFT.owner(), user1);
        assertEq(deviceNFT.operator(), operator1);
    }
    
    function test_CreateDeviceNFTWithZeroOperator() public {
        vm.prank(user1);
        address clone = factory.createDeviceNFT(NAME1, SYMBOL1, address(0));
        
        DeviceNFTTemplate deviceNFT = DeviceNFTTemplate(clone);
        assertEq(deviceNFT.operator(), address(0));
        assertEq(deviceNFT.owner(), user1);
    }
    
    function test_CloneIndependence() public {
        // Create two clones
        vm.prank(user1);
        address clone1 = factory.createDeviceNFT(NAME1, SYMBOL1, operator1);
        
        vm.prank(user2);
        address clone2 = factory.createDeviceNFT(NAME2, SYMBOL2, operator2);
        
        DeviceNFTTemplate deviceNFT1 = DeviceNFTTemplate(clone1);
        DeviceNFTTemplate deviceNFT2 = DeviceNFTTemplate(clone2);
        
        // Mint token in first clone
        vm.prank(user1);
        deviceNFT1.mint(user1, 1);
        
        // Verify token exists in first clone but not second
        assertEq(deviceNFT1.balanceOf(user1), 1);
        assertEq(deviceNFT2.balanceOf(user1), 0);
        
        // Change operator in first clone
        vm.prank(user1);
        deviceNFT1.setOperator(user2);
        
        // Verify operators are different
        assertEq(deviceNFT1.operator(), user2);
        assertEq(deviceNFT2.operator(), operator2);
    }
    
    function test_CloneFunctionality() public {
        vm.prank(user1);
        address cloneAddress = factory.createDeviceNFT(NAME1, SYMBOL1, operator1);
        
        DeviceNFTTemplate clone = DeviceNFTTemplate(cloneAddress);
        
        // Test minting by owner
        vm.prank(user1);
        clone.mint(user2, 1);
        assertEq(clone.ownerOf(1), user2);
        
        // Test minting by operator
        vm.prank(operator1);
        clone.mint(user2, 2);
        assertEq(clone.ownerOf(2), user2);
        
        // Test batch minting
        address[] memory recipients = new address[](2);
        uint256[] memory tokenIds = new uint256[](2);
        recipients[0] = user1;
        recipients[1] = user2;
        tokenIds[0] = 3;
        tokenIds[1] = 4;
        
        vm.prank(operator1);
        clone.batchMint(recipients, tokenIds);
        assertEq(clone.ownerOf(3), user1);
        assertEq(clone.ownerOf(4), user2);
        
        // Test burning
        vm.prank(user1);
        clone.burn(1);
        vm.expectRevert(); // ERC721NonexistentToken
        clone.ownerOf(1);
    }
    
    function test_ImplementationCannotBeInitialized() public {
        // The implementation contract is not pre-initialized
        // This test verifies that we can initialize it once
        implementation.initialize("Test", "TEST", user1, operator1);
        
        // But not twice
        vm.expectRevert(); // InvalidInitialization()
        implementation.initialize("Test2", "TEST2", user2, operator2);
    }
    
    function test_CloneCannotBeReinitializedDirectly() public {
        vm.prank(user1);
        address cloneAddress = factory.createDeviceNFT(NAME1, SYMBOL1, operator1);
        
        DeviceNFTTemplate clone = DeviceNFTTemplate(cloneAddress);
        
        // Try to reinitialize the clone
        vm.expectRevert(); // InvalidInitialization()
        clone.initialize("New Name", "NEW", user2, operator2);
    }
    
    function test_ManyClones() public {
        uint256 numClones = 10;
        address[] memory clones = new address[](numClones);
        
        // Create multiple clones
        for (uint256 i = 0; i < numClones; i++) {
            vm.prank(user1);
            clones[i] = factory.createDeviceNFT(
                string(abi.encodePacked("Device", vm.toString(i))),
                string(abi.encodePacked("DEV", vm.toString(i))),
                operator1
            );
        }
        
        // Verify all clones are different and properly initialized
        for (uint256 i = 0; i < numClones; i++) {
            assertTrue(clones[i] != address(0));
            
            DeviceNFTTemplate clone = DeviceNFTTemplate(clones[i]);
            assertEq(clone.owner(), user1);
            assertEq(clone.operator(), operator1);
            assertEq(clone.name(), string(abi.encodePacked("Device", vm.toString(i))));
            assertEq(clone.symbol(), string(abi.encodePacked("DEV", vm.toString(i))));
            
            // Verify it's different from all previous clones
            for (uint256 j = 0; j < i; j++) {
                assertTrue(clones[i] != clones[j]);
            }
        }
    }
    
    function test_FactoryWithDifferentImplementations() public {
        // Create a second implementation
        DeviceNFTTemplate implementation2 = new DeviceNFTTemplate();
        
        // Create a second factory
        vm.prank(deployer);
        DeviceNFTFactory factory2 = new DeviceNFTFactory(address(implementation2));
        
        // Create clones from both factories
        vm.prank(user1);
        address clone1 = factory.createDeviceNFT(NAME1, SYMBOL1, operator1);
        
        vm.prank(user1);
        address clone2 = factory2.createDeviceNFT(NAME1, SYMBOL1, operator1);
        
        // Clones should be different
        assertTrue(clone1 != clone2);
        
        // Both should work the same way
        DeviceNFTTemplate deviceNFT1 = DeviceNFTTemplate(clone1);
        DeviceNFTTemplate deviceNFT2 = DeviceNFTTemplate(clone2);
        
        vm.prank(user1);
        deviceNFT1.mint(user1, 1);
        
        vm.prank(user1);
        deviceNFT2.mint(user1, 1);
        
        assertEq(deviceNFT1.ownerOf(1), user1);
        assertEq(deviceNFT2.ownerOf(1), user1);
    }
}
