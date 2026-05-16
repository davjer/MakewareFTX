// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

interface IUGINFTCore {
    function ownerOf(uint256 tokenId) external view returns (address);

    function setExposureLock(uint256 id, bool locked) external;

    function bindLoanResult(uint256 nftId, bytes32 requestId, bool success) external;

    function getReputation(uint256 id)
        external
        view
        returns (
            uint256 score,
            uint256 lastUpdate,
            uint8 tier,
            bool broken,
            uint256 breakTimestamp
        );
}