// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract UGIReputationNFT is ERC721, AccessControl {

    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");

    uint256 public nextId;

    struct Reputation {
        uint256 score;
        uint256 successes;
        uint256 defaults;
        bool blacklisted;
    }

    struct LoanRecord {
        uint256 amount;
        bool repaid;
        uint256 timestamp;
    }

    mapping(address => uint256) public userToToken;
    mapping(uint256 => Reputation) public reputation;
    mapping(uint256 => LoanRecord[]) public history;

    constructor() ERC721("UGI Reputation", "UGI-R") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    // ----------------------------
    // CREATE PARENT
    // ----------------------------
    function mintIdentity(address user) external {
        require(userToToken[user] == 0, "EXISTS");

        uint256 id = ++nextId;
        userToToken[user] = id;

        _mint(user, id);
    }

    // ----------------------------
    // UPDATE FROM ORACLE
    // ----------------------------
    function recordLoan(
        address user,
        uint256 amount,
        bool repaid
    ) external onlyRole(ORACLE_ROLE) {

        uint256 id = userToToken[user];
        require(id != 0, "NO_IDENTITY");

        history[id].push(
            LoanRecord(amount, repaid, block.timestamp)
        );

        Reputation storage rep = reputation[id];

        if (repaid) {
            rep.successes++;
            rep.score += 10;
        } else {
            rep.defaults++;
            rep.score = rep.score > 20 ? rep.score - 20 : 0;

            if (rep.defaults >= 3) {
                rep.blacklisted = true;
            }
        }
    }

    // ----------------------------
    // VIEW
    // ----------------------------
    function getReputation(address user)
        external
        view
        returns (Reputation memory)
    {
        return reputation[userToToken[user]];
    }
}