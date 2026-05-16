// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

interface IRiskInterestEngine {
    function getAPR(uint256 nftId) external view returns (uint256);
}