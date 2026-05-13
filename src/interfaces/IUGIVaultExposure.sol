// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

interface IUGIVaultExposure {
    function hasActiveExposure(uint256 nftId)
        external
        view
        returns (bool);
}