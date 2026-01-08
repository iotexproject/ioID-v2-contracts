// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {IoIDRegistryBatchWrapper} from "../src/ioIDRegistry/ioIDRegistryBatchWrapper.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

// Mock contracts for testing
contract MockIoIDRegistry {
    mapping(bytes32 => bool) public registered;
    address public operator;
    
    constructor(address _operator) {
        operator = _operator;
    }
    
    function registerDeviceNFT(
        bytes32 ioIDIdentifier,
        uint256 chainID,
        bytes memory NFTcontract,
        uint256 tokenID
    ) external {
        require(msg.sender == operator, "Not operator");
        registered[ioIDIdentifier] = true;
    }

    function setOperator(address _operator) external {
        operator = _operator;
    }
}

contract MockERC6551Registry {
    uint256 private accountCounter;
    
    function createAccount(
        address implementation,
        bytes32 salt,
        uint256 chainId,
        address tokenContract,
        uint256 tokenId
    ) external returns (address) {
        accountCounter++;
        // Create a deterministic address for testing
        address account = address(uint160(uint256(keccak256(abi.encodePacked(
            implementation,
            salt,
            chainId,
            tokenContract,
            tokenId,
            accountCounter
        )))));
        
        // Deploy mock account proxy
        MockAccountProxy proxy = new MockAccountProxy();
        return address(proxy);
    }
    
    function account(
        address implementation,
        bytes32 salt,
        uint256 chainId,
        address tokenContract,
        uint256 tokenId
    ) external pure returns (address) {
        return address(uint160(uint256(keccak256(abi.encodePacked(
            implementation,
            salt,
            chainId,
            tokenContract,
            tokenId
        )))));
    }
}

contract MockAccountProxy {
    bool public initialized;
    address public implementation;
    
    function initialize(address _implementation) external {
        require(!initialized, "Already initialized");
        initialized = true;
        implementation = _implementation;
    }
}

contract IoIDRegistryBatchWrapperTest is Test {
    IoIDRegistryBatchWrapper public batchWrapper;
    MockIoIDRegistry public mockIoIDRegistry;
    MockERC6551Registry public mockERC6551Registry;
    address public mockAccountProxy;
    address public mockAccountUpgradable;
    bytes32 public constant SALT = 0x0000000000000000000000000000000000000000000000000000000000000000;
    address public operator;
    address public nonOperator;
    
    function setUp() public {
        operator = address(this);
        nonOperator = address(0x9999);
        
        // Deploy mock contracts
        mockIoIDRegistry = new MockIoIDRegistry(operator);
        mockERC6551Registry = new MockERC6551Registry();
        mockAccountProxy = address(0x1111);
        mockAccountUpgradable = address(0x2222);
        
        // Deploy batch wrapper
        batchWrapper = new IoIDRegistryBatchWrapper(
            operator, // owner
            address(mockIoIDRegistry),
            address(mockERC6551Registry),
            mockAccountProxy,
            mockAccountUpgradable,
            SALT
        );
    }
    
    function testConstructor() public view {
        assertEq(batchWrapper.ioIDRegistry(), address(mockIoIDRegistry));
        assertEq(batchWrapper.erc6551Registry(), address(mockERC6551Registry));
        assertEq(batchWrapper.accountImplementationProxy(), mockAccountProxy);
        assertEq(batchWrapper.accountImplementationUpgradable(), mockAccountUpgradable);
        assertEq(batchWrapper.accountSalt(), SALT);
        assertEq(batchWrapper.owner(), operator);
    }
    
    function testBatchRegister() public {
        mockIoIDRegistry.setOperator(address(batchWrapper));

        bytes32[] memory ioIDIdentifiers = new bytes32[](3);
        uint256[] memory chainIDs = new uint256[](3);
        address[] memory nftContracts = new address[](3);
        uint256[] memory tokenIDs = new uint256[](3);
        
        for (uint256 i = 0; i < 3; i++) {
            ioIDIdentifiers[i] = keccak256(abi.encodePacked("device", i));
            chainIDs[i] = 4689;
            nftContracts[i] = address(uint160(0x3333 + i));
            tokenIDs[i] = i + 1;
        }
        
        // Call batchRegister
        address[] memory accountAddresses = batchWrapper.batchRegister(
            ioIDIdentifiers,
            chainIDs,
            nftContracts,
            tokenIDs
        );
        
        // Verify all accounts were created
        assertEq(accountAddresses.length, 3);
        for (uint256 i = 0; i < 3; i++) {
            assertTrue(accountAddresses[i] != address(0));
            assertTrue(mockIoIDRegistry.registered(ioIDIdentifiers[i]));
        }
    }
    
    function testBatchRegisterWrapperNotOperator() public {
        bytes32[] memory ioIDIdentifiers = new bytes32[](1);
        uint256[] memory chainIDs = new uint256[](1);
        address[] memory nftContracts = new address[](1);
        uint256[] memory tokenIDs = new uint256[](1);
        
        ioIDIdentifiers[0] = keccak256("device1");
        chainIDs[0] = 4689;
        nftContracts[0] = address(0x3333);
        tokenIDs[0] = 1;
        
        // Wrapper is not operator (operator is address(this))
        assertFalse(mockIoIDRegistry.operator() == address(batchWrapper));
        
        vm.expectRevert("Not operator");
        batchWrapper.batchRegister(
            ioIDIdentifiers,
            chainIDs,
            nftContracts,
            tokenIDs
        );
    }
    
    function testBatchRegisterArrayMismatch() public {
        bytes32[] memory ioIDIdentifiers = new bytes32[](2);
        uint256[] memory chainIDs = new uint256[](3);
        address[] memory nftContracts = new address[](2);
        uint256[] memory tokenIDs = new uint256[](2);
        
        // Expect revert due to array length mismatch
        vm.expectRevert("Array length mismatch");
        batchWrapper.batchRegister(
            ioIDIdentifiers,
            chainIDs,
            nftContracts,
            tokenIDs
        );
    }
    
    function testOnlyOwnerCanCallBatchRegister() public {
        bytes32[] memory ioIDIdentifiers = new bytes32[](1);
        uint256[] memory chainIDs = new uint256[](1);
        address[] memory nftContracts = new address[](1);
        uint256[] memory tokenIDs = new uint256[](1);

        ioIDIdentifiers[0] = keccak256("device1");
        chainIDs[0] = 4689;
        nftContracts[0] = address(0x3333);
        tokenIDs[0] = 1;

        vm.prank(nonOperator);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonOperator));
        batchWrapper.batchRegister(
            ioIDIdentifiers,
            chainIDs,
            nftContracts,
            tokenIDs
        );
    }
    
    function testConstructorInvalidAddresses() public {
        // Test invalid IoID registry address
        vm.expectRevert("Invalid IoID registry address");
        new IoIDRegistryBatchWrapper(
            operator,
            address(0),
            address(mockERC6551Registry),
            mockAccountProxy,
            mockAccountUpgradable,
            SALT
        );

        // Test invalid ERC6551 registry address
        vm.expectRevert("Invalid ERC6551 registry address");
        new IoIDRegistryBatchWrapper(
            operator,
            address(mockIoIDRegistry),
            address(0),
            mockAccountProxy,
            mockAccountUpgradable,
            SALT
        );

        // Test invalid account proxy address
        vm.expectRevert("Invalid account proxy address");
        new IoIDRegistryBatchWrapper(
            operator,
            address(mockIoIDRegistry),
            address(mockERC6551Registry),
            address(0),
            mockAccountUpgradable,
            SALT
        );

        // Test invalid account upgradable address
        vm.expectRevert("Invalid account upgradable address");
        new IoIDRegistryBatchWrapper(
            operator,
            address(mockIoIDRegistry),
            address(mockERC6551Registry),
            mockAccountProxy,
            address(0),
            SALT
        );
    }
}
