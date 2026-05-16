// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import "forge-std/Test.sol";

import "../../contracts/v1/UGINFTCore.sol";
import "../../interfaces/IUGINFTCore.sol";

contract NFTHandler is Test {

    IUGINFTCore public nft;

    constructor(IUGINFTCore _nft) {
        nft = _nft;
    }

    function reward(uint256 id, uint256 amount) public {

        id = bound(id, 1, 1000);
        amount = bound(amount, 1, 100);

        // no-op fuzz trigger (no direct hook in V1)
        id;
        amount;
    }

    function penalize(uint256 id, uint256 amount) public {

        id = bound(id, 1, 1000);
        amount = bound(amount, 1, 100);

        // no-op fuzz trigger (no direct hook in V1)
        id;
        amount;
    }
}