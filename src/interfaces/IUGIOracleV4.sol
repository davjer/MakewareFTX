// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

interface IUGIOracleV4 {

    struct Request {
        address executor;
        address user;
        bytes32 requestId;
    }

    function execute(Request calldata req, bytes calldata sig)
        external
        returns (bool approved, uint256 maxAmount);
}