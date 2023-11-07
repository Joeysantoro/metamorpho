// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

struct MarketConfig {
    /// @notice The maximum amount of assets that can be allocated to the market.
    uint192 cap;
    /// @notice Whether the market is in the withdraw queue.
    bool enabled;
    /// @notice The timestamp at which the market can be instantly removed from the withdraw queue.
    uint48 removableAt;
}

struct PendingUint192 {
    /// @notice The pending value to set.
    uint192 value;
    /// @notice The timestamp at which the pending value becomes valid.
    uint48 validAt;
}

struct PendingAddress {
    /// @notice The pending value to set.
    address value;
    /// @notice The timestamp at which the pending value becomes valid.
    uint48 validAt;
}

/// @title PendingLib
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Library to manage pending values and their validity timestamp.
library PendingLib {
    /// @dev Updates `pending`'s value to `newValue` and its corresponding `validAt` timestamp.
    /// @dev Assumes `timelock` <= `MAX_TIMELOCK`.
    function update(PendingUint192 storage pending, uint192 newValue, uint256 timelock) internal {
        pending.value = newValue;
        // Safe "unchecked" cast because timelock <= MAX_TIMELOCK.
        pending.validAt = uint48(block.timestamp) + uint48(timelock);
    }

    /// @dev Updates `pending`'s value to `newValue` and its corresponding `validAt` timestamp.
    /// @dev Assumes `timelock` <= `MAX_TIMELOCK`.
    function update(PendingAddress storage pending, address newValue, uint256 timelock) internal {
        pending.value = newValue;
        // Safe "unchecked" cast because timelock <= MAX_TIMELOCK.
        pending.validAt = uint48(block.timestamp) + uint48(timelock);
    }

    /// @dev Marks the market associated to the given config as removable starting `timelock` seconds in the future.
    /// @dev Assumes `timelock` <= `MAX_TIMELOCK`.
    function disable(MarketConfig storage config, uint256 timelock) internal {
        config.cap = 0;
        // Safe "unchecked" cast because timelock <= MAX_TIMELOCK.
        config.removableAt = uint48(block.timestamp) + uint48(timelock);
    }
}
