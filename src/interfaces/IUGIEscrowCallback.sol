// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

interface IUGIEscrowCallback {
    function onEscrowResolved(
        uint256 loanId,
        uint256 escrowId,
        bool success,
        uint256 releasedAmount
    ) external;
}