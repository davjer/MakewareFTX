contract Invariant_OracleSecurity {

    /*
    RULES:

    1. requestId cannot be reused
    2. nonce must always increment
    3. signature must match signer role
    4. expired requests cannot execute
    */

    function invariant_NoReplayAttack() public {}

    function invariant_NonceMonotonic() public {}

    function invariant_SignatureValidity() public {}
}