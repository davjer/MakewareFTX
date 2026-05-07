// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract MAKEWARENFTX is ERC721URIStorage, AccessControl {

    // -----------------------------
    // ROLES
    // -----------------------------
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");

    // -----------------------------
    // TOKEN
    // -----------------------------
    uint256 public tokenId;

    // -----------------------------
    // CONSTANTS
    // -----------------------------
    uint256 public constant MAX_SCORE_DELTA = 50;
    uint256 public constant MINT_FEE = 0.01 ether;

    // -----------------------------
    // IDENTITY STATE
    // -----------------------------
    enum Tier { LOW, BASIC, TRUSTED, PRIME }

    struct Profile {
        uint256 score;
        uint256 backing;
        uint256 valuation;
        uint256 yieldRate;
        uint256 lastUpdate;
        Tier tier;
        bool exists;
    }

    mapping(uint256 => Profile) public profiles;

    // -----------------------------
    // SOCIAL / ID GRAPH
    // -----------------------------
    mapping(uint256 => uint256) public parent;
    mapping(uint256 => uint256[]) public children;

    // -----------------------------
    // AUDIT HASH SYSTEM
    // -----------------------------
    mapping(bytes32 => bool) public usedHashes;
    mapping(uint256 => uint256) public lastHashTime;

    // -----------------------------
    // EVENTS
    // -----------------------------
    event Minted(uint256 indexed tokenId, address owner);

    event ScoreUpdated(uint256 indexed tokenId, int256 delta);
    event TierUpdated(uint256 indexed tokenId, Tier tier);
    event ValuationUpdated(uint256 indexed tokenId, uint256 value);

    event PostHash(
        uint256 indexed tokenId,
        bytes32 hash,
        uint256 timestamp
    );

    // -----------------------------
    // INIT
    // -----------------------------
    constructor() ERC721("MAKEWARENFTX", "MWNFTX") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ORACLE_ROLE, msg.sender);
    }

    // =====================================================
    // 🪪 MINT
    // =====================================================
    function mint(
        address to,
        string memory uri,
        uint256 parentId
    ) external payable returns (uint256) {

        require(msg.value >= MINT_FEE, "Mint fee required");

        tokenId++;

        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);

        profiles[tokenId] = Profile({
            score: 100,
            backing: 0,
            valuation: 0,
            yieldRate: 0,
            lastUpdate: block.timestamp,
            tier: Tier.BASIC,
            exists: true
        });

        if (parentId != 0) {
            require(profiles[parentId].exists, "Parent not found");
            parent[tokenId] = parentId;
            children[parentId].push(tokenId);
        }

        _updateTier(tokenId);
        _refreshValuation(tokenId);

        emit Minted(tokenId, to);

        return tokenId;
    }

    // =====================================================
    // 🔐 ORACLE SCORE UPDATE
    // =====================================================
    function updateScore(uint256 id, int256 delta)
        external
        onlyRole(ORACLE_ROLE)
    {
        require(profiles[id].exists, "NFT not found");

        require(
            block.timestamp - profiles[id].lastUpdate > 1 hours,
            "Cooldown active"
        );

        require(delta <= int256(MAX_SCORE_DELTA), "Delta too high");
        require(delta >= -int256(MAX_SCORE_DELTA), "Delta too low");

        Profile storage p = profiles[id];

        if (delta < 0) {
            uint256 absDelta = uint256(-delta);
            if (absDelta >= p.score) {
                p.score = 0;
            } else {
                p.score -= absDelta;
            }
        } else {
            p.score += uint256(delta);
        }

        p.lastUpdate = block.timestamp;

        _updateTier(id);
        _refreshValuation(id);

        emit ScoreUpdated(id, delta);
    }

    // =====================================================
    // 📊 TIER SYSTEM
    // =====================================================
    function _updateTier(uint256 id) internal {
        Profile storage p = profiles[id];

        Tier old = p.tier;

        if (p.score < 50) {
            p.tier = Tier.LOW;
        } else if (p.score < 100) {
            p.tier = Tier.BASIC;
        } else if (p.score < 200) {
            p.tier = Tier.TRUSTED;
        } else {
            p.tier = Tier.PRIME;
        }

        if (old != p.tier) {
            emit TierUpdated(id, p.tier);
        }
    }

    // =====================================================
    // 💰 VALUATION ENGINE
    // =====================================================
    function _refreshValuation(uint256 id) internal {
        Profile storage p = profiles[id];

        p.valuation =
            p.backing +
            (p.score * 1e15) +
            (p.yieldRate * 1e14);

        emit ValuationUpdated(id, p.valuation);
    }

    // =====================================================
    // 🧱 BACKING (COLLATERAL)
    // =====================================================
    function addBacking(uint256 id) external payable {
        require(profiles[id].exists, "NFT not found");
        require(msg.value > 0, "Zero value");

        profiles[id].backing += msg.value;

        _refreshValuation(id);
    }

    // =====================================================
    // 📜 USER POST HASH (AUDIT / PORTFOLIO)
    // =====================================================
    function emitUserHash(uint256 tokenId, bytes32 hash) external {
        require(ownerOf(tokenId) == msg.sender, "Not owner");

        _emitHash(tokenId, hash);
    }

    // =====================================================
    // 🔐 ORACLE VERIFIED HASH
    // =====================================================
    function emitVerifiedHash(uint256 tokenId, bytes32 hash)
        external
        onlyRole(ORACLE_ROLE)
    {
        _emitHash(tokenId, hash);
    }

    // =====================================================
    // INTERNAL HASH LOGIC
    // =====================================================
    function _emitHash(uint256 tokenId, bytes32 hash) internal {

        require(profiles[tokenId].exists, "NFT not found");

        require(!usedHashes[hash], "Hash already used");

        require(
            block.timestamp - lastHashTime[tokenId] > 10 minutes,
            "Hash spam protection"
        );

        usedHashes[hash] = true;
        lastHashTime[tokenId] = block.timestamp;

        emit PostHash(tokenId, hash, block.timestamp);
    }

    // =====================================================
    // VIEW FOR VAULT
    // =====================================================
    function getProfile(uint256 id)
        external
        view
        returns (
            uint256 score,
            uint256 backing,
            uint256 valuation,
            Tier tier
        )
    {
        Profile memory p = profiles[id];
        return (p.score, p.backing, p.valuation, p.tier);
    }
}