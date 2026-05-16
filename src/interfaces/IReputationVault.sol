// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

interface IReputationVault {

    function onEscrowResolved(
        uint256 loanId,
        uint256 escrowId,
        bool success,
        uint256 releasedAmount
    ) external;

    function onLiquidityBorrow(uint256 amount) external;

    function onLiquidityRepay(uint256 amount) external;
}