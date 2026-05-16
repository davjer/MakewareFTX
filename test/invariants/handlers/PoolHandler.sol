// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import "forge-std/Test.sol";

import "../../contracts/v1/LiquidityPool.sol";
import "../../interfaces/ILiquidityPool.sol";

contract PoolHandler is Test {

    ILiquidityPool public pool;

    constructor(ILiquidityPool _pool) {
        pool = _pool;
    }

    function deposit(uint256 amount) public {

        amount = bound(
            amount,
            0.1 ether,
            10 ether
        );

        (bool ok,) = address(pool).call(
            abi.encodeWithSignature(
                "deposit(uint256)",
                amount
            )
        );

        require(ok, "DEPOSIT_FAIL");
    }

    function withdraw(uint256 amount) public {

        amount = bound(
            amount,
            0.1 ether,
            5 ether
        );

        (bool ok,) = address(pool).call(
            abi.encodeWithSignature(
                "withdraw(uint256)",
                amount
            )
        );

        require(ok, "WITHDRAW_FAIL");
    }
}