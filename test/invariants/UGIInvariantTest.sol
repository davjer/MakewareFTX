// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import "./BaseInvariantTest.sol";

contract UGIInvariantTest is BaseInvariantTest {

    // ----------------------------
    // 1. LIQUIDITY CONSISTENCY
    // ----------------------------

    function invariant_ExposureMatchesPool() public view {
        assertEq(
            vault.totalExposure(),
            pool.exposure()
        );
    }

    // ----------------------------
    // 2. POOL ACCOUNTING
    // ----------------------------

    function invariant_NoNegativeLiquidity() public view {
        assertGe(
            pool.totalAssets(),
            pool.totalBorrowed()
        );
    }

    // ----------------------------
    // 3. ACTIVE LOAN ACCOUNTING
    // ----------------------------

    function invariant_LoanIntegrity() public view {
        assertGe(
            vault.totalActiveLoans(),
            0
        );
    }

    // ----------------------------
    // 4. SYSTEM SOLVENCY
    // ----------------------------

    function invariant_SystemSolvent() public view {
        assertGe(
            pool.totalAssets(),
            pool.totalBorrowed()
        );
    }

    // ----------------------------
    // 5. AVAILABLE LIQUIDITY
    // ----------------------------

    function invariant_AvailableLiquiditySafe() public view {
        assertLe(
            pool.totalAvailable(),
            pool.totalAssets()
        );
    }

    // ----------------------------
    // 6. SHARE ACCOUNTING
    // ----------------------------

    function invariant_ShareValueSafe() public view {
        if (pool.totalShares() == 0) return;

        assertGt(
            pool.shareValue(),
            0
        );
    }

    // ----------------------------
    // 7. VAULT EXPOSURE SAFE
    // ----------------------------

    function invariant_ExposureNeverExceedsAssets() public view {
        assertLe(
            vault.totalExposure(),
            pool.totalAssets()
        );
    }
}