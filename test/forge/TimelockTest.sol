// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./helpers/BaseTest.sol";

uint256 constant TIMELOCK = 1 weeks;

contract TimelockTest is BaseTest {
    using MarketParamsLib for MarketParams;

    function setUp() public override {
        super.setUp();

        // block.timestamp defaults to 1 which is an unrealistic state: block.timestamp < TIMELOCK.
        vm.warp(block.timestamp + TIMELOCK);

        _setTimelock(TIMELOCK);
    }

    function testSubmitTimelockIncreased(uint256 timelock) public {
        timelock = bound(timelock, TIMELOCK + 1, MAX_TIMELOCK);

        vm.prank(OWNER);
        vault.submitTimelock(timelock);

        uint256 newTimelock = vault.timelock();
        (uint256 pendingTimelock, uint64 submittedAt) = vault.pendingTimelock();

        assertEq(newTimelock, timelock, "newTimelock");
        assertEq(pendingTimelock, 0, "pendingTimelock");
        assertEq(submittedAt, 0, "submittedAt");
    }

    function testSubmitTimelockDecreased(uint256 timelock) public {
        timelock = bound(timelock, 0, TIMELOCK - 1);

        vm.prank(OWNER);
        vault.submitTimelock(timelock);

        uint256 newTimelock = vault.timelock();
        (uint256 pendingTimelock, uint64 submittedAt) = vault.pendingTimelock();

        assertEq(newTimelock, TIMELOCK, "newTimelock");
        assertEq(pendingTimelock, timelock, "pendingTimelock");
        assertEq(submittedAt, block.timestamp, "submittedAt");
    }

    function testSubmitTimelockNotOwner(uint256 timelock) public {
        vm.expectRevert("Ownable: caller is not the owner");
        vault.submitTimelock(timelock);
    }

    function testSubmitTimelockMaxTimelockExceeded(uint256 timelock) public {
        timelock = bound(timelock, MAX_TIMELOCK + 1, type(uint256).max);

        vm.prank(OWNER);
        vm.expectRevert(bytes(ErrorsLib.MAX_TIMELOCK_EXCEEDED));
        vault.submitTimelock(timelock);
    }

    function testAcceptTimelockDecreased(uint256 timelock) public {
        timelock = bound(timelock, 0, TIMELOCK - 1);

        vm.prank(OWNER);
        vault.submitTimelock(timelock);

        vm.warp(block.timestamp + TIMELOCK);

        vm.prank(OWNER);
        vault.acceptTimelock();

        uint256 newTimelock = vault.timelock();
        (uint256 pendingTimelock, uint64 submittedAt) = vault.pendingTimelock();

        assertEq(newTimelock, timelock, "newTimelock");
        assertEq(pendingTimelock, 0, "pendingTimelock");
        assertEq(submittedAt, 0, "submittedAt");
    }

    function testAcceptTimelockNoPendingValue() public {
        vm.expectRevert(bytes(ErrorsLib.NO_PENDING_VALUE));
        vault.acceptTimelock();
    }

    function testAcceptTimelockNotOwner(uint256 timelock) public {
        timelock = bound(timelock, 0, TIMELOCK - 1);

        vm.prank(OWNER);
        vault.submitTimelock(timelock);

        vm.warp(block.timestamp + TIMELOCK);

        vm.expectRevert("Ownable: caller is not the owner");
        vault.acceptTimelock();
    }

    function testAcceptTimelockNotElapsed(uint256 elapsed) public {
        elapsed = bound(elapsed, 1, TIMELOCK - 1);

        vm.prank(OWNER);
        vault.submitTimelock(0);

        vm.warp(block.timestamp + elapsed);

        vm.prank(OWNER);
        vm.expectRevert(bytes(ErrorsLib.TIMELOCK_NOT_ELAPSED));
        vault.acceptTimelock();
    }

    function testAcceptTimelockDecreasedTimelockExpirationExceeded(uint256 timelock, uint256 elapsed) public {
        timelock = bound(timelock, 0, TIMELOCK - 1);
        elapsed = bound(elapsed, TIMELOCK + TIMELOCK_EXPIRATION + 1, type(uint64).max);

        vm.prank(OWNER);
        vault.submitTimelock(timelock);

        vm.warp(block.timestamp + elapsed);

        vm.prank(OWNER);
        vm.expectRevert(bytes(ErrorsLib.TIMELOCK_EXPIRATION_EXCEEDED));
        vault.acceptTimelock();
    }

    function testAcceptCap(uint256 seed, uint256 cap) public {
        MarketParams memory marketParams = allMarkets[seed % allMarkets.length];
        cap = bound(cap, 1, type(uint192).max);

        vm.prank(RISK_MANAGER);
        vault.submitCap(marketParams, cap);

        Id id = marketParams.id();
        (uint192 pendingCapBefore, uint64 submittedAtBefore) = vault.pendingCap(id);

        assertEq(pendingCapBefore, cap, "pendingCapBefore");
        assertEq(submittedAtBefore, block.timestamp, "submittedAtBefore");

        vm.warp(block.timestamp + TIMELOCK);

        vm.prank(RISK_MANAGER);
        vault.acceptCap(id);

        (uint192 newCap, uint64 withdrawRank) = vault.config(id);
        (uint192 pendingCapAfter, uint64 submittedAtAfter) = vault.pendingCap(id);

        assertEq(newCap, cap, "newCap");
        assertEq(withdrawRank, 1, "withdrawRank");
        assertEq(pendingCapAfter, 0, "pendingCapAfter");
        assertEq(submittedAtAfter, 0, "submittedAtAfter");
        assertEq(Id.unwrap(vault.supplyQueue(0)), Id.unwrap(id), "supplyQueue");
        assertEq(Id.unwrap(vault.withdrawQueue(0)), Id.unwrap(id), "withdrawQueue");
    }

    function testAcceptCapNoPendingValue() public {
        vm.expectRevert(bytes(ErrorsLib.NO_PENDING_VALUE));
        vault.acceptCap(allMarkets[0].id());
    }

    function testAcceptCapTimelockNotElapsed(uint256 alpsed) public {
        alpsed = bound(alpsed, 0, TIMELOCK - 1);

        vm.prank(RISK_MANAGER);
        vault.submitCap(allMarkets[0], CAP);

        vm.warp(block.timestamp + alpsed);

        vm.prank(RISK_MANAGER);
        vm.expectRevert(bytes(ErrorsLib.TIMELOCK_NOT_ELAPSED));
        vault.acceptCap(allMarkets[0].id());
    }

    function testAcceptCapTimelockExpirationExceeded(uint256 timelock, uint256 timeElapsed) public {
        timelock = bound(timelock, 1, MAX_TIMELOCK);

        vm.assume(timelock != vault.timelock());

        _setTimelock(timelock);

        timeElapsed = bound(timeElapsed, timelock + TIMELOCK_EXPIRATION + 1, type(uint64).max);

        vm.startPrank(RISK_MANAGER);
        vault.submitCap(allMarkets[0], CAP);

        vm.warp(block.timestamp + timeElapsed);

        vm.expectRevert(bytes(ErrorsLib.TIMELOCK_EXPIRATION_EXCEEDED));
        vault.acceptCap(allMarkets[0].id());
    }

    function testDecreaseCapNoTimelock(uint256 seed, uint256 cap, uint256 cap2) public {
        MarketParams memory marketParams = allMarkets[seed % allMarkets.length];
        cap = bound(cap, 1, type(uint192).max);
        cap2 = bound(cap2, 0, cap - 1);

        _setCap(marketParams, cap);

        vm.prank(RISK_MANAGER);
        vault.submitCap(marketParams, cap2);

        (uint192 newCap, uint64 withdrawRank) = vault.config(marketParams.id());

        assertEq(newCap, cap2, "newCap");
        assertEq(withdrawRank, 1, "withdrawRank");
    }
}
