// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

library PoolStructs {
    struct Pool {
        bytes32 id;
        address[] assets;
        uint256[] lockupDurations;
        uint256 apr;
        address poolToken;
        bool isActive;
        uint256 feePercentage;
    }
    
    struct NodedPool {
        uint256[] lockupDurations;
        uint256[] apys;
        bool isActive;
        uint256 fee;
    }
}
