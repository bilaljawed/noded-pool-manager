// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

/// @title ParamStructs
/// @notice Contains parameter structs used in PoolManager for staking and unstaking functions
library ParamStructs {

    /// @notice Struct to encapsulate the parameters for staking
    struct StakeParams {
        bytes32 poolId;
        address[] assets;
        uint256[] amounts;
        uint256 lockupIndex;
        bytes userData;
    }

    /// @notice Struct to encapsulate the parameters for unstaking
    struct UnstakeParams {
        bytes32 poolId;
        uint256 stakeIndex;
        address[] assets;
        uint256[] amounts;
        bytes userData;
    }
}
