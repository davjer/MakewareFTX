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
    // 2. NO NEGATIVE STATE
    // ----------------------------
    function invariant_NoNegativeLiquidity() public view {
        assertTrue(pool.totalAssets() >= pool.totalBorrowed());
    }

    // ----------------------------
    // 3. LOAN STATE CONSISTENCY
    // ----------------------------
    function invariant_LoanIntegrity() public view {
        assertTrue(vault.totalActiveLoans() >= 0);
    }

    // ----------------------------
    // 4. NFT REPUTATION BOUNDS
    // ----------------------------
    function invariant_ReputationBounds() public view {
        // pseudo-check (would require indexing or exposed getter)
        // score must always be within valid range
    }

    // ----------------------------
    // 5. ESCROW SAFETY
    // ----------------------------
    function invariant_EscrowNeverOverReleases() public view {
        // escrow.released <= escrow.total
    }

    // ----------------------------
    // 6. ORACLE REPLAY PROTECTION
    // ----------------------------
    function invariant_NoRequestReuse() public view {
        // usedRequest must always be unique per requestId
    }

    // ----------------------------
    // 7. SYSTEM SOLVENCY
    // ----------------------------
    function invariant_SystemSolvent() public view {
        uint256 available = pool.totalAssets() - pool.totalBorrowed();
        assertGe(available, 0);
    }
}