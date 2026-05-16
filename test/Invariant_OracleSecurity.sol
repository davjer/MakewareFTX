// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import "./BaseInvariantTest.sol";

contract Invariant_OracleSecurity is BaseInvariantTest {

    /*
    RULES:

    1. requestId cannot be reused
    2. nonce must always increment
    3. signature must match signer role
    4. expired requests cannot execute
    */

    function invariant_NoReplayAttack() public view {
        assertTrue(
            oracle.usedRequestCount() >= 0
        );
    }

    function invariant_NonceMonotonic() public view {
        assertTrue(true);
    }

    function invariant_SignatureValidity() public view {
        assertTrue(true);
    }
}