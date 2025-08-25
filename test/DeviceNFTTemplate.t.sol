// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/deviceNFT/DeviceNFTTemplate.sol";

contract DeviceNFTTemplateTest is Test {
    DeviceNFTTemplate public deviceNFT;
    
    address public owner = makeAddr("owner");
    address public operator = makeAddr("operator");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    address public unauthorizedUser = makeAddr("unauthorized");
    
    string public constant NAME = "Device NFT";
    string public constant SYMBOL = "DNFT";
    
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    
    function setUp() public {
        deviceNFT = new DeviceNFTTemplate();
        
        // Initialize the contract
        deviceNFT.initialize(NAME, SYMBOL, owner, operator);
    }
    
    function test_Initialize() public {
        // Test initialization values
        assertEq(deviceNFT.name(), NAME);
        assertEq(deviceNFT.symbol(), SYMBOL);
        assertEq(deviceNFT.owner(), owner);
        assertEq(deviceNFT.operator(), operator);
    }
    
    function test_InitializeCannotBeCalledTwice() public {
        vm.expectRevert(); // InvalidInitialization()
        deviceNFT.initialize("New Name", "NEW", owner, operator);
    }
    
    function test_SetOperator() public {
        address newOperator = makeAddr("newOperator");
        
        vm.prank(owner);
        deviceNFT.setOperator(newOperator);
        
        assertEq(deviceNFT.operator(), newOperator);
    }
    
    function test_SetOperatorOnlyOwner() public {
        address newOperator = makeAddr("newOperator");
        
        vm.prank(unauthorizedUser);
        vm.expectRevert(); // OwnableUnauthorizedAccount
        deviceNFT.setOperator(newOperator);
    }
    
    function test_MintByOwner() public {
        uint256 tokenId = 1;
        
        vm.prank(owner);
        deviceNFT.mint(user1, tokenId);
        
        assertEq(deviceNFT.ownerOf(tokenId), user1);
        assertEq(deviceNFT.balanceOf(user1), 1);
    }
    
    function test_MintByOperator() public {
        uint256 tokenId = 1;
        
        vm.prank(operator);
        deviceNFT.mint(user1, tokenId);
        
        assertEq(deviceNFT.ownerOf(tokenId), user1);
        assertEq(deviceNFT.balanceOf(user1), 1);
    }
    
    function test_MintUnauthorized() public {
        uint256 tokenId = 1;
        
        vm.prank(unauthorizedUser);
        vm.expectRevert("Only owner or operator can mint");
        deviceNFT.mint(user1, tokenId);
    }
    
    function test_MintExistingToken() public {
        uint256 tokenId = 1;
        
        // Mint first time
        vm.prank(owner);
        deviceNFT.mint(user1, tokenId);
        
        // Try to mint same token again
        vm.prank(owner);
        vm.expectRevert(); // ERC721InvalidSender
        deviceNFT.mint(user2, tokenId);
    }
    
    function test_BatchMintByOwner() public {
        address[] memory recipients = new address[](3);
        uint256[] memory tokenIds = new uint256[](3);
        
        recipients[0] = user1;
        recipients[1] = user2;
        recipients[2] = user1; // user1 gets two tokens
        
        tokenIds[0] = 1;
        tokenIds[1] = 2;
        tokenIds[2] = 3;
        
        vm.prank(owner);
        deviceNFT.batchMint(recipients, tokenIds);
        
        assertEq(deviceNFT.ownerOf(1), user1);
        assertEq(deviceNFT.ownerOf(2), user2);
        assertEq(deviceNFT.ownerOf(3), user1);
        assertEq(deviceNFT.balanceOf(user1), 2);
        assertEq(deviceNFT.balanceOf(user2), 1);
    }
    
    function test_BatchMintByOperator() public {
        address[] memory recipients = new address[](2);
        uint256[] memory tokenIds = new uint256[](2);
        
        recipients[0] = user1;
        recipients[1] = user2;
        
        tokenIds[0] = 1;
        tokenIds[1] = 2;
        
        vm.prank(operator);
        deviceNFT.batchMint(recipients, tokenIds);
        
        assertEq(deviceNFT.ownerOf(1), user1);
        assertEq(deviceNFT.ownerOf(2), user2);
    }
    
    function test_BatchMintUnauthorized() public {
        address[] memory recipients = new address[](1);
        uint256[] memory tokenIds = new uint256[](1);
        
        recipients[0] = user1;
        tokenIds[0] = 1;
        
        vm.prank(unauthorizedUser);
        vm.expectRevert("Only owner or operator can mint");
        deviceNFT.batchMint(recipients, tokenIds);
    }
    
    function test_BatchMintMismatchedArrays() public {
        address[] memory recipients = new address[](2);
        uint256[] memory tokenIds = new uint256[](1); // Mismatched length
        
        recipients[0] = user1;
        recipients[1] = user2;
        tokenIds[0] = 1;
        
        vm.prank(owner);
        // This should fail due to array bounds
        vm.expectRevert();
        deviceNFT.batchMint(recipients, tokenIds);
    }
    
    function test_BatchMintEmpty() public {
        address[] memory recipients = new address[](0);
        uint256[] memory tokenIds = new uint256[](0);
        
        vm.prank(owner);
        deviceNFT.batchMint(recipients, tokenIds);
        // Should complete without error but not mint anything
    }
    
    function test_Burn() public {
        uint256 tokenId = 1;
        
        // First mint a token
        vm.prank(owner);
        deviceNFT.mint(user1, tokenId);
        
        assertEq(deviceNFT.ownerOf(tokenId), user1);
        
        // Burn the token
        vm.prank(owner);
        deviceNFT.burn(tokenId);
        
        // Token should no longer exist
        vm.expectRevert(); // ERC721NonexistentToken
        deviceNFT.ownerOf(tokenId);
        
        assertEq(deviceNFT.balanceOf(user1), 0);
    }
    
    function test_BurnOnlyOwner() public {
        uint256 tokenId = 1;
        
        // First mint a token
        vm.prank(owner);
        deviceNFT.mint(user1, tokenId);
        
        // Try to burn as unauthorized user
        vm.prank(unauthorizedUser);
        vm.expectRevert("Only owner can burn");
        deviceNFT.burn(tokenId);
        
        // Try to burn as operator (should also fail)
        vm.prank(operator);
        vm.expectRevert("Only owner can burn");
        deviceNFT.burn(tokenId);
        
        // Token should still exist
        assertEq(deviceNFT.ownerOf(tokenId), user1);
    }
    
    function test_BurnNonExistentToken() public {
        uint256 tokenId = 999;
        
        vm.prank(owner);
        vm.expectRevert(); // ERC721NonexistentToken
        deviceNFT.burn(tokenId);
    }
    
    function test_TransferOwnership() public {
        address newOwner = makeAddr("newOwner");
        
        vm.prank(owner);
        deviceNFT.transferOwnership(newOwner);
        
        assertEq(deviceNFT.owner(), newOwner);
    }
    
    function test_RenounceOwnership() public {
        vm.prank(owner);
        deviceNFT.renounceOwnership();
        
        assertEq(deviceNFT.owner(), address(0));
    }
    
    function test_OperatorCannotSetOperator() public {
        address newOperator = makeAddr("newOperator");
        
        vm.prank(operator);
        vm.expectRevert(); // OwnableUnauthorizedAccount
        deviceNFT.setOperator(newOperator);
    }
    
    function test_StandardERC721Functions() public {
        uint256 tokenId = 1;
        
        // Mint token
        vm.prank(owner);
        deviceNFT.mint(user1, tokenId);
        
        // Test ERC721 functions
        assertEq(deviceNFT.balanceOf(user1), 1);
        assertEq(deviceNFT.ownerOf(tokenId), user1);
        
        // Test approval
        vm.prank(user1);
        deviceNFT.approve(user2, tokenId);
        assertEq(deviceNFT.getApproved(tokenId), user2);
        
        // Test transfer
        vm.prank(user2);
        deviceNFT.transferFrom(user1, user2, tokenId);
        assertEq(deviceNFT.ownerOf(tokenId), user2);
        assertEq(deviceNFT.balanceOf(user1), 0);
        assertEq(deviceNFT.balanceOf(user2), 1);
    }
    
    function test_SupportsInterface() public {
        // Test ERC721 interface support
        assertTrue(deviceNFT.supportsInterface(0x80ac58cd)); // ERC721
        assertTrue(deviceNFT.supportsInterface(0x5b5e139f)); // ERC721Metadata
        assertTrue(deviceNFT.supportsInterface(0x01ffc9a7)); // ERC165
    }
}
