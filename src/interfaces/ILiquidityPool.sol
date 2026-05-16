// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

interface ILiquidityPool {

    function borrow(uint256 amount) external;

    function repay(uint256 principal, uint256 interest) external;

}