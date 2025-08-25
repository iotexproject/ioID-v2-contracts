# ioID v2 Contracts

This project contains the smart contracts for ioID v2, a system for creating and managing NFTs for devices. It uses the Foundry framework for development, testing, and deployment.

## Overview

The core of this project is a factory pattern for creating `DeviceNFT` contracts. Each `DeviceNFT` contract is an ERC721 token that represents a unique device.

### Contracts

*   `src/deviceNFT/DeviceNFTFactory.sol`: This is the main factory contract. It has a `createDeviceNFT` function that deploys a new `DeviceNFT` contract (clone) for a user.
*   `src/deviceNFT/DeviceNFTTemplate.sol`: This is the template contract for the `DeviceNFT`. It's an upgradeable ERC721 contract with minting controlled by an owner and an operator.

## Getting Started

### Prerequisites

*   [Foundry](https://getfoundry.sh/)

### Installation

1.  Clone the repository:
    ```shell
    git clone <repository-url>
    cd ioID-v2-contracts
    ```
2.  Install dependencies:
    ```shell
    forge install
    ```

### Build

To build the contracts, run:

```shell
forge build
```

### Test

To run the tests, run:

```shell
forge test
```

### Deploy

The project includes a deployment script in `script/DeployDeviceNFT.s.sol`. To deploy the contracts, you can use the following command:

```shell
forge script script/DeployDeviceNFT.s.sol:DeployDeviceNFT --rpc-url <your_rpc_url> --private-key <your_private_key>
```

Make sure to replace `<your_rpc_url>` and `<your_private_key>` with your actual RPC URL and private key.

## Dependencies

This project uses the following libraries:

*   [forge-std](https://github.com/foundry-rs/forge-std): Standard library for Foundry projects.
*   [openzeppelin-contracts](https://github.com/OpenZeppelin/openzeppelin-contracts): A library for secure smart contract development.
*   [openzeppelin-contracts-upgradeable](https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable): Upgradeable versions of OpenZeppelin Contracts.

These dependencies are managed using `git submodules` and are located in the `lib/` directory.

