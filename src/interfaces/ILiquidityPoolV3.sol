// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

interface ILiquidityPoolV3 {

    function borrow(uint256 amount) external;

    function repay(uint256 amount) external;
}