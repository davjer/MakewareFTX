// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

contract UGIOracleV3 is EIP712, AccessControl, Pausable {
    using ECDSA for bytes32;

    bytes32 public constant SIGNER_ROLE = keccak256("SIGNER_ROLE");

    address public immutable vault;

    mapping(bytes32 => bool) public usedRequest;
    mapping(address => uint256) public nonces;

    struct Request {
        address executor;
        bytes32 requestId;
        address user;
        bytes payload;
        uint256 deadline;
        uint256 nonce;
    }

    struct Payload {
        uint256 amount;
        uint8 tier;
        bytes32 nftId;
    }

    bytes32 private constant TYPEHASH =
        keccak256(
            "Request(address executor,bytes32 requestId,address user,bytes payload,uint256 deadline,uint256 nonce)"
        );

    bytes32 private constant PAYLOAD_TYPEHASH =
        keccak256("Payload(uint256 amount,uint8 tier,bytes32 nftId)");

    event RequestExecuted(
        bytes32 indexed requestId,
        address indexed user,
        bytes32 indexed nftId,
        uint256 maxAmount,
        uint8 tier,
        address signer
    );

    constructor(address _vault)
        EIP712("UGIOracle", "1")
    {
        require(_vault != address(0), "ZERO_VAULT");
        vault = _vault;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function setSigner(address signer)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(signer != address(0), "ZERO_SIGNER");
        _grantRole(SIGNER_ROLE, signer);
    }

    function execute(
        Request calldata req,
        bytes calldata sig
    )
        external
        whenNotPaused
        returns (bool approved, uint256 maxAmount)
    {
        require(msg.sender == vault, "NOT_VAULT");
        require(req.executor == vault, "BAD_EXECUTOR");
        require(!usedRequest[req.requestId], "REPLAY");
        require(block.timestamp <= req.deadline, "EXPIRED");
        require(nonces[req.user] == req.nonce, "BAD_NONCE");

        Payload memory p = abi.decode(req.payload, (Payload));

        bytes32 payloadHash = keccak256(
            abi.encode(
                PAYLOAD_TYPEHASH,
                p.amount,
                p.tier,
                p.nftId
            )
        );

        bytes32 structHash = keccak256(
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

        bytes32 digest = _hashTypedDataV4(structHash);
        address signer = digest.recover(sig);

        require(hasRole(SIGNER_ROLE, signer), "BAD_SIGNER");

        usedRequest[req.requestId] = true;
        nonces[req.user]++;

        approved = p.amount > 0;
        maxAmount = p.amount;

        emit RequestExecuted(
            req.requestId,
            req.user,
            p.nftId,
            p.amount,
            p.tier,
            signer
        );

        return (approved, maxAmount);
    }

    function domainSeparator()
        external
        view
        returns (bytes32)
    {
        return _domainSeparatorV4();
    }
}