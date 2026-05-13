contract Invariant_EscrowConsistency {

    /*
    RULES:

    1. sum(milestones) == escrow.totalAmount
    2. releasedAmount ≤ totalAmount
    3. resolved escrow cannot be modified
    4. callback must match loanId
    */

    function invariant_MilestoneAccounting() public {}

    function invariant_NoDoubleRelease() public {}

    function invariant_CallbackIntegrity() public {}
}