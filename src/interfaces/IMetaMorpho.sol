// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import {IMorpho, Id, MarketParams} from "@morpho-blue/interfaces/IMorpho.sol";
import {IERC4626} from "@openzeppelin/interfaces/IERC4626.sol";

import {MarketConfig, PendingUint192, PendingAddress} from "../libraries/PendingLib.sol";

/// @dev Either `assets` or `shares` should be zero.
struct MarketAllocation {
    /// @notice The market to allocate.
    MarketParams marketParams;
    /// @notice The amount of assets to allocate.
    uint256 assets;
    /// @notice The amount of shares to allocate.
    uint256 shares;
}

interface IMetaMorpho is IERC4626 {
    function MORPHO() external view returns (IMorpho);

    function curator() external view returns (address);
    function isAllocator(address target) external view returns (bool);
    function guardian() external view returns (address);

    function fee() external view returns (uint96);
    function feeRecipient() external view returns (address);
    function rewardsRecipient() external view returns (address);
    function timelock() external view returns (uint256);
    function supplyQueue(uint256) external view returns (Id);
    function supplyQueueLength() external view returns (uint256);
    function withdrawQueue(uint256) external view returns (Id);
    function withdrawQueueLength() external view returns (uint256);
    function config(Id) external view returns (uint192 cap, bool enabled, uint48 disabledAt);

    function idle() external view returns (uint256);
    function lastTotalAssets() external view returns (uint256);

    function submitTimelock(uint256 newTimelock) external;
    function acceptTimelock() external;
    function revokePendingTimelock() external;
    function pendingTimelock() external view returns (uint192 value, uint48 validAt);

    function submitCap(MarketParams memory marketParams, uint256 supplyCap) external;
    function acceptCap(Id id) external;
    function revokePendingCap(Id id) external;
    function pendingCap(Id) external view returns (uint192 value, uint48 validAt);

    function submitFee(uint256 newFee) external;
    function acceptFee() external;
    function pendingFee() external view returns (uint192 value, uint48 validAt);

    function submitGuardian(address newGuardian) external;
    function acceptGuardian() external;
    function revokePendingGuardian() external;
    function pendingGuardian() external view returns (address guardian, uint48 validAt);

    function transferRewards(address) external;

    function setIsAllocator(address newAllocator, bool newIsAllocator) external;
    function setCurator(address newCurator) external;
    function setFeeRecipient(address newFeeRecipient) external;
    function setRewardsRecipient(address) external;

    function setSupplyQueue(Id[] calldata newSupplyQueue) external;
    function updateWithdrawQueue(uint256[] calldata indexes) external;
    function reallocate(MarketAllocation[] calldata withdrawn, MarketAllocation[] calldata supplied) external;
}

interface IPending {
    function pendingTimelock() external view returns (PendingUint192 memory);
    function pendingCap(Id) external view returns (PendingUint192 memory);
    function pendingGuardian() external view returns (PendingAddress memory);
}
