// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

import "../interfaces/IUGIOracle.sol";
import "../interfaces/IUGINFTCore.sol";

contract UGIOracle is
    EIP712,
    AccessControl,
    Pausable,
    IUGIOracle
{
    using ECDSA for bytes32;

    // -------------------------------------------------
    // ROLES
    // -------------------------------------------------

    bytes32 public constant SIGNER_ROLE =
        keccak256("SIGNER_ROLE");

    // -------------------------------------------------
    // IMMUTABLES
    // -------------------------------------------------

    address public immutable vault;

    IUGINFTCore public immutable nft;

    // -------------------------------------------------
    // STORAGE
    // -------------------------------------------------

    mapping(bytes32 => bool) public usedRequest;

    mapping(address => uint256) public nonces;

    mapping(bytes32 => bool) public revokedDigests;

    uint256 public maxApprovalWindow =
        15 minutes;

    // -------------------------------------------------
    // STRUCTS
    // -------------------------------------------------

    struct Request {

        // must be vault
        address executor;

        // unique request
        bytes32 requestId;

        // wallet owner
        address user;

        // encoded payload
        bytes payload;

        // expiration
        uint256 deadline;

        // replay protection
        uint256 nonce;
    }

    struct Payload {

        // approved max loan
        uint256 amount;

        // tier snapshot
        uint8 tier;

        // NFT binding
        uint256 nftId;

        // reputation snapshot
        uint256 score;

        // chain where signed
        uint256 chainId;

        // approval timestamp
        uint256 issuedAt;

        // risk flags
        bool requireKYC;

        // optional future expansion
        bytes32 riskHash;
    }

    // -------------------------------------------------
    // TYPEHASHES
    // -------------------------------------------------

    bytes32 private constant TYPEHASH =
        keccak256(
            "Request(address executor,bytes32 requestId,address user,bytes payload,uint256 deadline,uint256 nonce)"
        );

    bytes32 private constant PAYLOAD_TYPEHASH =
        keccak256(
            "Payload(uint256 amount,uint8 tier,uint256 nftId,uint256 score,uint256 chainId,uint256 issuedAt,bool requireKYC,bytes32 riskHash)"
        );

    // -------------------------------------------------
    // EVENTS
    // -------------------------------------------------

    event RequestExecuted(
        bytes32 indexed requestId,
        address indexed user,
        uint256 indexed nftId,
        uint256 maxAmount,
        uint8 tier,
        uint256 score,
        address signer
    );

    event DigestRevoked(
        bytes32 indexed digest
    );

    event SignerAdded(
        address indexed signer
    );

    event SignerRemoved(
        address indexed signer
    );

    // -------------------------------------------------
    // CONSTRUCTOR
    // -------------------------------------------------

    constructor(
        address _vault,
        address _nft
    )
        EIP712("UGIOracle", "1")
    {
        require(
            _vault != address(0),
            "ZERO_VAULT"
        );

        require(
            _nft != address(0),
            "ZERO_NFT"
        );

        vault = _vault;

        nft = IUGINFTCore(_nft);

        _grantRole(
            DEFAULT_ADMIN_ROLE,
            msg.sender
        );
    }

    // -------------------------------------------------
    // ADMIN
    // -------------------------------------------------

    function setSigner(address signer)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(
            signer != address(0),
            "ZERO"
        );

        _grantRole(
            SIGNER_ROLE,
            signer
        );

        emit SignerAdded(signer);
    }

    function removeSigner(address signer)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _revokeRole(
            SIGNER_ROLE,
            signer
        );

        emit SignerRemoved(signer);
    }

    function setMaxApprovalWindow(
        uint256 window
    )
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(window > 0, "ZERO");

        maxApprovalWindow = window;
    }

    function revokeDigest(bytes32 digest)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        revokedDigests[digest] = true;

        emit DigestRevoked(digest);
    }

    function pause()
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _pause();
    }

    function unpause()
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _unpause();
    }

    // -------------------------------------------------
    // EXECUTION
    // -------------------------------------------------

    function execute(
        Request calldata req,
        bytes calldata sig
    )
        external
        whenNotPaused
        returns (
            bool approved,
            uint256 maxAmount
        )
    {
        require(
            msg.sender == vault,
            "NOT_VAULT"
        );

        require(
            req.executor == vault,
            "BAD_EXECUTOR"
        );

        require(
            !usedRequest[req.requestId],
            "REPLAY"
        );

        require(
            block.timestamp <= req.deadline,
            "EXPIRED"
        );

        require(
            nonces[req.user] == req.nonce,
            "BAD_NONCE"
        );

        Payload memory p =
            abi.decode(
                req.payload,
                (Payload)
            );

        // -------------------------------------------------
        // PAYLOAD VALIDATION
        // -------------------------------------------------

        require(
            p.chainId == block.chainid,
            "BAD_CHAIN"
        );

        require(
            block.timestamp <=
            p.issuedAt +
            maxApprovalWindow,
            "STALE_APPROVAL"
        );

        require(
            nft.ownerOf(p.nftId) ==
            req.user,
            "NOT_NFT_OWNER"
        );

        (
            uint256 liveScore,
            ,
            uint8 liveTier,
            bool broken,

        ) = nft.getReputation(
                p.nftId
            );

        require(
            !broken,
            "BROKEN_CHAIN"
        );

        require(
            liveTier == p.tier,
            "TIER_CHANGED"
        );

        require(
            liveScore >= p.score,
            "SCORE_DEGRADED"
        );

        // -------------------------------------------------
        // EIP712 HASHING
        // -------------------------------------------------

        bytes32 payloadHash =
            keccak256(
                abi.encode(
                    PAYLOAD_TYPEHASH,
                    p.amount,
                    p.tier,
                    p.nftId,
                    p.score,
                    p.chainId,
                    p.issuedAt,
                    p.requireKYC,
                    p.riskHash
                )
            );

        bytes32 structHash =
            keccak256(
                abi.encode(
                    TYPEHASH,
                    req.executor,
                    req.requestId,
                    req.user,
                    payloadHash,
                    req.deadline,
                    req.nonce
                )
            );

        bytes32 digest =
            _hashTypedDataV4(
                structHash
            );

        require(
            !revokedDigests[digest],
            "DIGEST_REVOKED"
        );

        address signer =
            digest.recover(sig);

        require(
            hasRole(
                SIGNER_ROLE,
                signer
            ),
            "BAD_SIGNER"
        );

        // -------------------------------------------------
        // STATE MUTATION
        // -------------------------------------------------

        usedRequest[
            req.requestId
        ] = true;

        nonces[req.user]++;

        approved = p.amount > 0;

        maxAmount = p.amount;

        emit RequestExecuted(
            req.requestId,
            req.user,
            p.nftId,
            p.amount,
            p.tier,
            p.score,
            signer
        );

        return (
            approved,
            maxAmount
        );
    }

    // -------------------------------------------------
    // VIEWS
    // -------------------------------------------------

    function domainSeparator()
        external
        view
        returns (bytes32)
    {
        return
            _domainSeparatorV4();
    }

    function computeDigest(
        Request calldata req
    )
        external
        view
        returns (bytes32)
    {
        Payload memory p =
            abi.decode(
                req.payload,
                (Payload)
            );

        bytes32 payloadHash =
            keccak256(
                abi.encode(
                    PAYLOAD_TYPEHASH,
                    p.amount,
                    p.tier,
                    p.nftId,
                    p.score,
                    p.chainId,
                    p.issuedAt,
                    p.requireKYC,
                    p.riskHash
                )
            );

        bytes32 structHash =
            keccak256(
                abi.encode(
                    TYPEHASH,
                    req.executor,
                    req.requestId,
                    req.user,
                    payloadHash,
                    req.deadline,
                    req.nonce
                )
            );

        return
            _hashTypedDataV4(
                structHash
            );
    }
}