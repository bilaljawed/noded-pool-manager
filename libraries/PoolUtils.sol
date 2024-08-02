// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "../structs/StakeStructs.sol";

library PoolUtils {
    using StakeStructs for StakeStructs.Stake;

    /// @notice Calculates the projected returns for a stake
    /// @param amount The amount of the stake
    /// @param apr The APR of the stake
    /// @param durationInSeconds The duration of the stake in seconds
    /// @return projectedInterest The projected interest for the stake
    function calculateProjectedReturns(
        uint256 amount,
        uint256 apr,
        uint256 durationInSeconds
    ) internal pure returns (uint256 projectedInterest) {
        projectedInterest = amount * apr * durationInSeconds / (365 days * 10000);
        return projectedInterest;
    }

    /// @notice Decodes user data
    /// @param userData The user data to be decoded
    /// @return value1 The first value in the user data
    /// @return value2 The second value in the user data
    function decodeUserData(bytes memory userData) internal pure returns (uint256 value1, uint256 value2) {
        require(userData.length == 64, "Invalid userData length");
        (value1, value2) = abi.decode(userData, (uint256, uint256));
        return (value1, value2);
    }
}
