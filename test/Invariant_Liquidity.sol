contract Invariant_Reputation {

    // CORE RULES:

    /*
    RULE 1:
    score must never exceed bounds (0–1000)

    RULE 2:
    broken NFT cannot increase score

    RULE 3:
    tier must match score thresholds

    RULE 4:
    decay must be monotonic per transfer cooldown
    */

    function invariant_ScoreBounds() public {
        // assert nft.score <= 1000
        // assert nft.score >= 0
    }

    function invariant_BrokenStateFrozen() public {
        // if broken == true:
        // reward() must not increase score
    }

    function invariant_TierConsistency() public {
        // validate tier mapping correctness
    }
}