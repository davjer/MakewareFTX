// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

interface IUGIEscrow {

    function create(
        address payer,
        address receiver,
        bytes32 requestId,
        uint256 loanId,
        uint256[] calldata milestones
    ) external returns (uint256);
}