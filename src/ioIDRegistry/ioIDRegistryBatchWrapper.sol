// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

interface IIoIDRegistry {
    function operator() external view returns (address);
    function registerDeviceNFT(
        bytes32 ioIDIdentifier,
        uint256 chainID,
        bytes memory NFTcontract,
        uint256 tokenID
    ) external;
}

interface IERC6551Registry {
    function createAccount(
        address implementation,
        bytes32 salt,
        uint256 chainId,
        address tokenContract,
        uint256 tokenId
    ) external returns (address);
}

interface IAccountProxy {
    function initialize(address implementation) external;
}

contract IoIDRegistryBatchWrapper is Ownable {
    address public immutable ioIDRegistry;
    address public immutable erc6551Registry;
    address public immutable accountImplementationProxy;
    address public immutable accountImplementationUpgradable;
    bytes32 public immutable accountSalt;

    event BatchRegistered(
        bytes32 indexed ioIDIdentifier,
        uint256 chainID,
        address nftContract,
        uint256 tokenID,
        address accountAddress
    );

    constructor(
        address owner,
        address _ioIDRegistry,
        address _erc6551Registry,
        address _accountImplementationProxy,
        address _accountImplementationUpgradable,
        bytes32 _accountSalt
    ) Ownable(owner) {
        require(_ioIDRegistry != address(0), "Invalid IoID registry address");
        require(_erc6551Registry != address(0), "Invalid ERC6551 registry address");
        require(_accountImplementationProxy != address(0), "Invalid account proxy address");
        require(_accountImplementationUpgradable != address(0), "Invalid account upgradable address");

        ioIDRegistry = _ioIDRegistry;
        erc6551Registry = _erc6551Registry;
        accountImplementationProxy = _accountImplementationProxy;
        accountImplementationUpgradable = _accountImplementationUpgradable;
        accountSalt = _accountSalt;
    }
    
    function batchRegister(
        bytes32[] calldata ioIDIdentifiers,
        uint256[] calldata chainIDs,
        address[] calldata nftContracts,
        uint256[] calldata tokenIDs
    ) external onlyOwner returns (address[] memory accountAddresses) {
        require(
            ioIDIdentifiers.length == chainIDs.length &&
            chainIDs.length == nftContracts.length &&
            nftContracts.length == tokenIDs.length,
            "Array length mismatch"
        );
        
        accountAddresses = new address[](ioIDIdentifiers.length);
        
        for (uint256 i = 0; i < ioIDIdentifiers.length; i++) {
            bytes memory nftContractBytes = abi.encodePacked(nftContracts[i]);
            IIoIDRegistry(ioIDRegistry).registerDeviceNFT(
                ioIDIdentifiers[i],
                chainIDs[i],
                nftContractBytes,
                tokenIDs[i]
            );
            
            accountAddresses[i] = IERC6551Registry(erc6551Registry).createAccount(
                accountImplementationProxy,
                accountSalt,
                chainIDs[i],
                nftContracts[i],
                tokenIDs[i]
            );
            
            IAccountProxy(accountAddresses[i]).initialize(accountImplementationUpgradable);
            
            emit BatchRegistered(ioIDIdentifiers[i], chainIDs[i], nftContracts[i], tokenIDs[i], accountAddresses[i]);
        }
        
        return accountAddresses;
    }
}
