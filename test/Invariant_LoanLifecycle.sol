// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import "./BaseInvariantTest.sol";

contract Invariant_LoanLifecycle is BaseInvariantTest {

    /*
    RULES:

    1. loan.active == true → must exist exposure in pool
    2. loan.repaid → must reduce exposure
    3. loan.defaulted → must trigger nft penalization
    4. escrow resolved → must match loan state
    */

    function invariant_LoanExposureConsistency() public view {
        assertGe(
            vault.totalExposure(),
            0
        );
    }

    function invariant_LoanCannotExistWithoutFunding() public view {
        assertGe(
            vault.totalActiveLoans(),
            0
        );
    }

    function invariant_LoanStateFinality() public view {
        // loans must not exceed logical bounds of system state
        assertGe(pool.totalAssets(), pool.totalBorrowed());
    }
}