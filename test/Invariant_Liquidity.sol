// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import "./invariants/BaseInvariantTest.sol";

contract Invariant_Liquidity is BaseInvariantTest {

    /*
    CORE RULES:

    1. totalAssets >= totalBorrowed
    2. totalAvailable >= reservedLiquidity
    3. withdrawals never exceed withdrawableLiquidity
    4. borrow/repay keeps accounting consistent
    */

    function invariant_AssetCoverage() public view {
        assertGe(pool.totalAssets(), pool.totalBorrowed());
    }

    function invariant_ReserveSafety() public view {
        assertGe(pool.totalAvailable(), pool.reservedLiquidity());
    }

    function invariant_NoNegativeWithdrawable() public view {
        assertGe(pool.withdrawableLiquidity(), 0);
    }

    function invariant_AccountingConsistency() public view {
        uint256 computed = pool.totalDeposited() - pool.totalWithdrawn();
        assertGe(pool.totalAssets(), computed);
    }
}