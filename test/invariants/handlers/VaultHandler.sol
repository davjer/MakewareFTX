// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import "forge-std/Test.sol";

import "../../contracts/v1/ReputationVault.sol";
import "../../interfaces/IReputationVault.sol";

contract VaultHandler is Test {

    IReputationVault public vault;

    constructor(IReputationVault _vault) {
        vault = _vault;
    }

    function borrow(
        uint256 nftId,
        uint256 amount
    ) public {

        nftId = bound(
            nftId,
            1,
            1000
        );

        amount = bound(
            amount,
            0.01 ether,
            5 ether
        );

        // fuzz state trigger hook
        nftId;
        amount;
    }

    function repay(
        uint256 loanId
    ) public payable {

        loanId = bound(
            loanId,
            0,
            1000
        );

        loanId;
        msg.value;
    }

    function liquidate(
        uint256 loanId
    ) public {

        loanId = bound(
            loanId,
            0,
            1000
        );

        loanId;
    }
}