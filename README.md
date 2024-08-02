# PoolManager Smart Contract

The `PoolManager` smart contract is a decentralized application designed to manage staking, unstaking, and pool management functionalities using Balancer's liquidity pools. It leverages OpenZeppelin's upgradeable contracts for enhanced security and upgradability.

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Usage](#usage)
- [Testing](#testing)
- [Contributing](#contributing)
- [License](#license)

## Overview

The `PoolManager` contract provides a secure and efficient mechanism for users to stake tokens, manage liquidity pools, and earn rewards based on their staked assets. It supports interaction with Balancer pools, allowing users to join and exit pools seamlessly.

## Features

- **Staking and Unstaking**: Users can stake tokens into specific pools and unstake them after a lockup period.
- **Pool Management**: Create, update, and delete liquidity pools with configurable parameters such as APR, lockup durations, and fees.
- **Noded Pool**: Special functionality for managing a Noded pool with specific staking logic.
- **Emergency Withdrawals**: Allows the owner to perform emergency withdrawals of tokens.
- **Upgradeable**: Built using OpenZeppelin's upgradeable contracts, supporting contract upgrades without data loss.
- **Secure**: Uses ReentrancyGuard and Ownable for security and access control.

## Architecture

The project is structured with a focus on modularity and code separation:

- **Contracts**:
  - `PoolManager.sol`: Main contract handling staking, unstaking, and pool management.
  - `interfaces/IBalancerPool.sol`: Interface for interacting with Balancer pools.
  - `structs/PoolStructs.sol`: Contains data structures related to pools.
  - `structs/StakeStructs.sol`: Contains data structures related to staking.
  - `structs/ParamStructs.sol`: Contains parameter structs for functions.
  - `libraries/PoolUtils.sol`: Utility library for calculations and data manipulation.

## Prerequisites

To develop and deploy this project, you will need:

- [Node.js](https://nodejs.org/) and [npm](https://www.npmjs.com/)
- [Hardhat](https://hardhat.org/) or [Truffle](https://www.trufflesuite.com/) for Ethereum development
- [OpenZeppelin Contracts](https://openzeppelin.com/contracts/)

## Installation

1. **Clone the repository**:

   ```bash
   git clone https://github.com/yourusername/your-repo-name.git
   cd your-repo-name
   ```

2. **Install dependencies**:

   ```bash
   npm install
   ```

3. **Compile the contracts**:

   If you are using Hardhat:

   ```bash
   npx hardhat compile
   ```

   If you are using Truffle:

   ```bash
   truffle compile
   ```

## Usage

1. **Deploy the contracts**:

   Create a deployment script in the `scripts` folder and execute it using Hardhat or Truffle. Example for Hardhat:

   ```bash
   npx hardhat run scripts/deploy.js --network your-network
   ```

2. **Interact with the contracts**:

   Use Hardhat console or Truffle console to interact with deployed contracts:

   ```bash
   npx hardhat console --network your-network
   ```

   Or

   ```bash
   truffle console --network your-network
   ```

3. **Example Commands**:

   ```javascript
   const poolManager = await ethers.getContractAt("PoolManager", "your_contract_address");

   // Stake tokens
   await poolManager.stake({
     poolId: "your_pool_id",
     assets: [],
     amounts: [],
     lockupIndex: 0,
     userData: "0x"
   });

   // Unstake tokens
   await poolManager.unstake({
     poolId: "your_pool_id",
     stakeIndex: 0,
     assets: [],
     amounts: [],
     userData: "0x"
   });

   // Create a new pool
   await poolManager.createPool("new_pool_id", [30, 60, 90], 500, true, 200);
   ```

## Testing

1. **Run Tests**:

   Use Hardhat or Truffle to run the test suite:

   ```bash
   npx hardhat test
   ```

   Or

   ```bash
   truffle test
   ```

2. **Test Coverage**:

   Ensure your tests cover all functionalities, especially edge cases and security scenarios.

## Contributing

We welcome contributions! Please follow these steps to contribute:

1. Fork the repository.
2. Create a new branch: `git checkout -b feature/your-feature-name`.
3. Make your changes and commit them: `git commit -m 'Add some feature'`.
4. Push to the branch: `git push origin feature/your-feature-name`.
5. Open a pull request.

Please ensure your code adheres to the project's coding conventions and standards.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
