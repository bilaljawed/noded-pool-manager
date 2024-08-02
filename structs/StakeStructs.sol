// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

library StakeStructs {
    struct Stake {
        uint256 amount;
        uint256 bptAmount;
        address assetAddress;
        uint256 startTime;
        uint256 lockupDuration;
        uint256 apr;
        address[] assets;
        uint256[] amounts;
    }

    struct NodedStake {
        uint256 amount;
        uint256 startTime;
        uint256 lockupDuration;
        uint256 apr;
    }

    struct StakeRequest {
        bytes32 poolId;
        address[] assets;
        uint256[] amounts;
        uint256 lockupIndex;
        bytes userData;
        uint256 assetAmount;
        uint256 bptAmount;
    }
}
