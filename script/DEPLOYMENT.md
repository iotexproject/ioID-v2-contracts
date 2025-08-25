# DeviceNFT Deployment Scripts

This directory contains Forge scripts for deploying the DeviceNFT contracts.

## Scripts

### `DeployDeviceNFT.s.sol`
Deployment script that deploys both contracts.

**Usage:**
```bash
# Deploy to local testnet
forge script script/DeployDeviceNFT.s.sol --fork-url http://localhost:8545 --broadcast

# Deploy to testnet (replace with your RPC URL)
forge script script/DeployDeviceNFT.s.sol --rpc-url $RPC_URL --broadcast --verify

# Deploy to mainnet (with additional confirmations)
forge script script/DeployDeviceNFT.s.sol --rpc-url $MAINNET_RPC_URL --broadcast --verify --slow
```

## Deployment Order

1. **DeviceNFTTemplate** - The implementation contract for the proxy pattern
2. **DeviceNFTFactory** - Factory contract that creates clones of the template

## Environment Variables

- `RPC_URL`: RPC endpoint for the target network
- `PRIVATE_KEY`: Deployer private key
- `ETHERSCAN_API_KEY`: For contract verification

## Post-Deployment

After deployment, you can:

1. **Create Device NFT instances** using the factory:
   ```solidity
   address deviceNFT = factory.createDeviceNFT("MyDevice", "MDV", operatorAddress);
   ```

2. **Verify contracts** on Etherscan:
   ```bash
   forge verify-contract --chain-id 1 --num-of-optimizations 200 --watch --constructor-args $(cast abi-encode "constructor(address)" $TEMPLATE_ADDRESS) $FACTORY_ADDRESS src/deviceNFT/DeviceNFTFactory.sol:DeviceNFTFactory --etherscan-api-key $ETHERSCAN_API_KEY
   ```

## Notes

- The DeviceNFTTemplate uses OpenZeppelin's upgradeable contracts
- The factory uses OpenZeppelin's Clones library for efficient proxy creation
- Each DeviceNFT instance is a minimal proxy pointing to the template implementation
