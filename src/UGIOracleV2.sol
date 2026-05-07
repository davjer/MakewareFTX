// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IUGINFTCoreV2 {
    function updateScore(uint256 id, int256 delta) external;
}

interface IReputationVaultV2 {
    function markDefault(uint256 loanId) external;
}

contract UGIOracleV2 {

    // -----------------------------
    // AUTH
    // -----------------------------
    address public admin;
    mapping(address => bool) public authorizedSigner;

    // -----------------------------
    // SECURITY
    // -----------------------------
    mapping(bytes32 => bool) public executed;
    mapping(address => uint256) public lastExecution;

    uint256 public constant RATE_LIMIT = 1 minutes;

    // -----------------------------
    // CONTRACTS
    // -----------------------------
    IUGINFTCoreV2 public nft;
    IReputationVaultV2 public vault;

    // -----------------------------
    // EVENTS
    // -----------------------------
    event Executed(
        bytes32 indexed requestId,
        uint8 actionType,
        uint256 targetId,
        int256 value,
        uint256 timestamp
    );

    // -----------------------------
    // ACTION TYPES
    // -----------------------------
    uint8 constant ACTION_SCORE = 0;
    uint8 constant ACTION_DEFAULT = 1;

    // -----------------------------
    // INIT
    // -----------------------------
    constructor(address nftAddress, address vaultAddress) {
        nft = IUGINFTCoreV2(nftAddress);
        vault = IReputationVaultV2(vaultAddress);

        admin = msg.sender;
        authorizedSigner[msg.sender] = true;
    }

    // =====================================================
    // 🔐 SIGNER MANAGEMENT
    // =====================================================
    function setSigner(address signer, bool status)
        external
    {
        require(msg.sender == admin, "not admin");
        authorizedSigner[signer] = status;
    }

    // =====================================================
    // 🔗 MAIN EXECUTION FUNCTION
    // =====================================================
    function execute(
        bytes32 requestId,
        uint8 actionType,
        uint256 targetId,
        int256 value,
        bytes memory signature
    ) external {

        require(!executed[requestId], "already executed");

        require(_verifySignature(requestId, actionType, targetId, value, signature),
            "invalid signature");

        require(
            block.timestamp - lastExecution[msg.sender] > RATE_LIMIT,
            "rate limited"
        );

        executed[requestId] = true;
        lastExecution[msg.sender] = block.timestamp;

        // =================================================
        // ROUTER
        // =================================================

        if (actionType == ACTION_SCORE) {

            nft.updateScore(targetId, value);

        } else if (actionType == ACTION_DEFAULT) {

            vault.markDefault(targetId);

        } else {
            revert("invalid action");
        }

        emit Executed(
            requestId,
            actionType,
            targetId,
            value,
            block.timestamp
        );
    }

    // =====================================================
    // 🔐 SIGNATURE VERIFICATION (SIMPLIFIED EIP-712 STYLE)
    // =====================================================
    function _verifySignature(
        bytes32 requestId,
        uint8 actionType,
        uint256 targetId,
        int256 value,
        bytes memory signature
    )
        internal
        view
        returns (bool)
    {
        bytes32 message = keccak256(
            abi.encodePacked(
                requestId,
                actionType,
                targetId,
                value
            )
        );

        address signer = _recoverSigner(message, signature);

        return authorizedSigner[signer];
    }

    // =====================================================
    // 🔐 RECOVER SIGNER
    // =====================================================
    function _recoverSigner(bytes32 hash, bytes memory sig)
        internal
        pure
        returns (address)
    {
        require(sig.length == 65, "bad sig");

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }

        return ecrecover(hash, v, r, s);
    }
}