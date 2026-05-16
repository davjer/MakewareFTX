// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import "forge-std/Test.sol";

import "../../contracts/v1/UGIOracle.sol";
import "../../interfaces/IUGIOracle.sol";

contract OracleHandler is Test {

    IUGIOracle public oracle;

    constructor(IUGIOracle _oracle) {
        oracle = _oracle;
    }

    function executeRequest(
        address executor,
        address user,
        bytes32 requestId,
        bytes calldata payload,
        uint256 deadline,
        uint256 nonce,
        bytes calldata sig
    ) public {

        executor = address(uint160(bound(uint256(uint160(executor)), 1, type(uint160).max)));
        user = address(uint160(bound(uint256(uint160(user)), 1, type(uint160).max)));

        deadline = bound(deadline, block.timestamp, block.timestamp + 30 days);
        nonce = bound(nonce, 0, type(uint256).max);

        IUGIOracle.Request memory req = IUGIOracle.Request({
            executor: executor,
            requestId: requestId,
            user: user,
            payload: payload,
            deadline: deadline,
            nonce: nonce
        });

        oracle.execute(req, sig);
    }
}