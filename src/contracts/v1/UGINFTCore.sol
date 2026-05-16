// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

import "../interfaces/IReputationVault.sol";
import "../interfaces/IVaultExposure.sol";

contract UGINFTCore is
    ERC721URIStorage,
    AccessControl,
    Pausable
{
    bytes32 public constant VAULT_ROLE =
        keccak256("VAULT_ROLE");

    uint256 public constant MINT_FEE = 0.01 ether;
    uint256 public nextId = 1;

    address public treasury;
    address public vault;

    bool public degradeOnTransfer = true;
    bool public exposureLockEnabled = true;

    uint256 public transferCooldown = 1 hours;

    enum Tier { LOW, BASIC, TRUSTED, PRIME }

    struct IdentityStatus {
        bool humanVerified;
        bool kycVerified;
        bool businessVerified;
        uint256 expiry;
        bytes32 providerId;
        uint16 providerVersion;
        bytes32 providerHash;
    }

    struct Reputation {
        uint256 score;
        uint256 lastUpdate;
        Tier tier;
        bool broken;
        uint256 breakTimestamp;
        uint256 lastTransferDecay;
    }

    mapping(uint256 => IdentityStatus) public identity;
    mapping(uint256 => Reputation) public reputation;

    mapping(uint256 => uint256) public parent;
    mapping(uint256 => uint256[]) internal _children;
    mapping(uint256 => mapping(uint256 => uint256)) internal childIndex;

    mapping(bytes32 => uint256) public requestToToken;
    mapping(bytes32 => bool) public usedRequestIds;

    mapping(uint256 => bool) public localExposureLock;

    event Minted(uint256 indexed id, address indexed owner);
    event ReputationUpdated(uint256 indexed id, uint256 score, Tier tier);
    event VaultUpdated(address indexed oldVault, address indexed newVault);
    event TreasuryUpdated(address indexed treasury);

    constructor(address _treasury)
        ERC721("UGI Trust Identity", "UGI")
    {
        require(_treasury != address(0), "ZERO");
        treasury = _treasury;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    modifier onlyVault() {
        require(msg.sender == vault, "NOT_VAULT");
        _;
    }

    modifier exists(uint256 id) {
        require(_ownerOf(id) != address(0), "NOT_EXISTS");
        _;
    }

    modifier notBroken(uint256 id) {
        require(!reputation[id].broken, "BROKEN");
        _;
    }

    // -------------------------------------------------
    // ADMIN
    // -------------------------------------------------

    function setVault(address newVault)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(newVault != address(0), "ZERO");

        address old = vault;

        if (old != address(0)) {
            _revokeRole(VAULT_ROLE, old);
        }

        vault = newVault;
        _grantRole(VAULT_ROLE, newVault);

        emit VaultUpdated(old, newVault);
    }

    function setTreasury(address _treasury)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(_treasury != address(0), "ZERO");
        treasury = _treasury;

        emit TreasuryUpdated(_treasury);
    }

    // -------------------------------------------------
    // MINT
    // -------------------------------------------------

    function mint(address to, string calldata uri)
        external
        payable
        whenNotPaused
        returns (uint256)
    {
        require(msg.value >= MINT_FEE, "FEE");
        require(to != address(0), "ZERO");

        uint256 id = nextId++;

        _safeMint(to, id);
        _setTokenURI(id, uri);

        reputation[id] = Reputation({
            score: 100,
            lastUpdate: block.timestamp,
            tier: Tier.BASIC,
            broken: false,
            breakTimestamp: 0,
            lastTransferDecay: 0
        });

        (bool ok,) = treasury.call{value: msg.value}("");
        require(ok, "TREASURY_FAIL");

        emit Minted(id, to);

        return id;
    }

    // -------------------------------------------------
    // VIEW HELPERS
    // -------------------------------------------------

    function hasExposureLock(uint256 id)
        public
        view
        returns (bool)
    {
        if (localExposureLock[id]) return true;
        if (vault == address(0)) return false;

        try IVaultExposure(vault).hasActiveExposure(id)
            returns (bool exposed)
        {
            return exposed;
        } catch {
            return false;
        }
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