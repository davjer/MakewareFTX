// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

interface IUGIOracle {

    struct Request {
        address executor;
        bytes32 requestId;
        address user;
        bytes payload;
        uint256 deadline;
        uint256 nonce;
    }

    function execute(
        Request calldata req,
        bytes calldata sig
    ) external returns (bool approved, uint256 maxAmount);
}