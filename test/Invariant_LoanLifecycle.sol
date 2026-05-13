contract Invariant_LoanLifecycle {

    /*
    RULES:

    1. loan.active == true → must exist exposure in pool
    2. loan.repaid → must reduce exposure
    3. loan.defaulted → must trigger nft penalization
    4. escrow resolved → must match loan state
    */

    function invariant_LoanExposureConsistency() public {}

    function invariant_LoanCannotExistWithoutFunding() public {}

    function invariant_LoanStateFinality() public {}
}