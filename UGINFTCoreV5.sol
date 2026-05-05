// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

contract UGINFTCoreV5 is ERC721URIStorage, AccessControl, Pausable {

    bytes32 public constant VAULT_ROLE = keccak256("VAULT_ROLE");

    uint256 private _nextId = 1;
    uint256 public constant MINT_FEE = 0.01 ether;

    address public treasury;

    enum Tier { LOW, BASIC, TRUSTED, PRIME }

    struct IdentityStatus {
        bool humanVerified;
        bool kycVerified;
        bool businessVerified;
        uint256 expiry;
        bytes32 providerHash;
    }

    struct Reputation {
        uint256 score;
        uint256 lastUpdate;
        Tier tier;
        bool broken;
        uint256 breakTimestamp;
    }

    mapping(uint256 => IdentityStatus) public identity;
    mapping(uint256 => Reputation) public reputation;

    mapping(uint256 => uint256) public parent;
    mapping(uint256 => uint256[]) public children;

    mapping(bytes32 => uint256) public requestToToken;
    mapping(bytes32 => bool) public usedRequestIds;

    bool public degradeOnTransfer = true;

    // ----------------------------
    // EVENTS
    // ----------------------------
    event Minted(uint256 id, address owner);
    event ReputationUpdated(uint256 id, uint256 score, Tier tier);
    event Linked(uint256 child, uint256 parent);
    event Detached(uint256 id);
    event Penalized(uint256 id, uint256 amount);
    event Rewarded(uint256 id, uint256 amount);
    event ChainBroken(uint256 id, uint256 timestamp);

    constructor(address _treasury)
        ERC721("UGI Trust Identity", "UGI")
    {
        require(_treasury != address(0), "ZERO_TREASURY");
        treasury = _treasury;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    // ----------------------------
    // ADMIN
    // ----------------------------
    function setVault(address vault)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _grantRole(VAULT_ROLE, vault);
    }

    function setTreasury(address _t)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(_t != address(0), "ZERO");
        treasury = _t;
    }

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    // ----------------------------
    // MODIFIERS
    // ----------------------------
    modifier notBroken(uint256 id) {
        require(!reputation[id].broken, "CHAIN_BROKEN");
        _;
    }

    // ----------------------------
    // MINT
    // ----------------------------
    function mint(address to, string memory uri)
        external
        payable
        whenNotPaused
        returns (uint256)
    {
        require(msg.value >= MINT_FEE, "FEE");

        uint256 id = _nextId++;

        _safeMint(to, id);
        _setTokenURI(id, uri);

        reputation[id] = Reputation({
            score: 100,
            lastUpdate: block.timestamp,
            tier: Tier.BASIC,
            broken: false,
            breakTimestamp: 0
        });

        payable(treasury).transfer(msg.value);

        emit Minted(id, to);
        return id;
    }

    // ----------------------------
    // GRAPH
    // ----------------------------
    function linkToParent(uint256 childId, uint256 parentId)
        external
        notBroken(childId)
    {
        require(ownerOf(childId) == msg.sender, "NOT_OWNER");
        require(childId != parentId, "SELF");

        parent[childId] = parentId;
        children[parentId].push(childId);

        emit Linked(childId, parentId);
    }

    function detach(uint256 id)
        external
        notBroken(id)
    {
        require(ownerOf(id) == msg.sender, "NOT_OWNER");

        delete parent[id];

        emit Detached(id);
    }

    // ----------------------------
    // IDENTITY
    // ----------------------------
    function setIdentity(
        uint256 id,
        bool human,
        bool kyc,
        bool business,
        uint256 expiry,
        bytes32 providerHash
    )
        external
        onlyRole(VAULT_ROLE)
        notBroken(id)
    {
        identity[id] = IdentityStatus(
            human,
            kyc,
            business,
            expiry,
            providerHash
        );
    }

    // ----------------------------
    // REPUTATION CORE
    // ----------------------------
    function reward(uint256 id, uint256 amount)
        external
        onlyRole(VAULT_ROLE)
        notBroken(id)
    {
        Reputation storage r = reputation[id];

        r.score += amount;
        _updateTier(id);

        emit Rewarded(id, amount);
    }

    function penalize(uint256 id, uint256 amount)
        external
        onlyRole(VAULT_ROLE)
        notBroken(id)
    {
        Reputation storage r = reputation[id];

        r.score = r.score > amount ? r.score - amount : 0;

        if (r.score < 100) {
            r.broken = true;
            r.breakTimestamp = block.timestamp;
            emit ChainBroken(id, block.timestamp);
        }

        _updateTier(id);

        emit Penalized(id, amount);
    }

    function bindLoanResult(
        uint256 id,
        bytes32 requestId,
        bool success
    )
        external
        onlyRole(VAULT_ROLE)
        notBroken(id)
    {
        require(!usedRequestIds[requestId], "USED");
        usedRequestIds[requestId] = true;

        requestToToken[requestId] = id;

        if (success) {
            reward(id, 20);
        } else {
            penalize(id, 30);
        }
    }

    // ----------------------------
    // TIER LOGIC
    // ----------------------------
    function _updateTier(uint256 id) internal {
        uint256 s = reputation[id].score;

        if (s > 800) reputation[id].tier = Tier.PRIME;
        else if (s > 600) reputation[id].tier = Tier.TRUSTED;
        else if (s > 300) reputation[id].tier = Tier.BASIC;
        else reputation[id].tier = Tier.LOW;

        reputation[id].lastUpdate = block.timestamp;

        emit ReputationUpdated(id, s, reputation[id].tier);
    }

    // ----------------------------
    // TRANSFER LOGIC
    // ----------------------------
    function _update(address to, uint256 tokenId, address auth)
        internal
        override
        returns (address)
    {
        address from = _ownerOf(tokenId);

        if (from != address(0) && degradeOnTransfer) {
            Reputation storage r = reputation[tokenId];

            r.score = r.score / 2;
            _updateTier(tokenId);
        }

        return super._update(to, tokenId, auth);
    }

    // ----------------------------
    // VIEW
    // ----------------------------
    function getReputation(uint256 id)
        external
        view
        returns (
            uint256 score,
            uint256 lastUpdate,
            Tier tier,
            bool broken,
            uint256 breakTimestamp
        )
    {
        Reputation memory r = reputation[id];
        return (r.score, r.lastUpdate, r.tier, r.broken, r.breakTimestamp);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721URIStorage, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}