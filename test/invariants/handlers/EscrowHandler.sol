// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import "forge-std/Test.sol";

import "../../contracts/v1/UGIEscrow.sol";
import "../../interfaces/IUGIEscrow.sol";

contract EscrowHandler is Test {

    IUGIEscrow public escrow;

    constructor(IUGIEscrow _escrow) {
        escrow = _escrow;
    }

    function release(uint256 id, uint256 milestoneId) public {

        id = bound(id, 0, 1000);
        milestoneId = bound(milestoneId, 0, 10);

        (bool ok,) = address(escrow).call(
            abi.encodeWithSignature(
                "releaseMilestone(uint256,uint256)",
                id,
                milestoneId
            )
        );

        require(ok, "RELEASE_FAIL");
    }

    function fail(uint256 id) public {

        id = bound(id, 0, 1000);

        (bool ok,) = address(escrow).call(
            abi.encodeWithSignature(
                "failEscrow(uint256)",
                id
            )
        );

        require(ok, "FAIL_ESCROW");
    }
}