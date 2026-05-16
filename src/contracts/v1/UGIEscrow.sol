// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

import "../interfaces/IReputationVault.sol";

contract UGIEscrow is
    AccessControl,
    ReentrancyGuard,
    Pausable
{
    // -------------------------------------------------
    // ROLES
    // -------------------------------------------------

    bytes32 public constant RESOLVER_ROLE =
        keccak256("RESOLVER_ROLE");

    bytes32 public constant VAULT_ROLE =
        keccak256("VAULT_ROLE");

    // -------------------------------------------------
    // STRUCTS
    // -------------------------------------------------

    struct Milestone {
        uint256 amount;
        bool approved;
        bool released;
        uint256 releasedAt;
    }

    struct Escrow {
        address payer;
        address receiver;
        uint256 totalAmount;
        uint256 releasedAmount;
        bytes32 requestId;
        uint256 loanId;
        bool funded;
        bool resolved;
        bool cancelled;
        bool success;
        uint256 milestoneCount;
        uint256 createdAt;
        uint256 resolvedAt;
    }

    // -------------------------------------------------
    // STORAGE
    // -------------------------------------------------

    mapping(uint256 => Escrow) public escrows;

    mapping(uint256 => mapping(uint256 => Milestone)) public milestones;

    mapping(bytes32 => uint256) public requestToEscrow;

    mapping(bytes32 => bool) public usedRequestIds;

    uint256 public escrowCounter;

    IReputationVault public vault;
    address public vaultAddress;

    // -------------------------------------------------
    // EVENTS
    // -------------------------------------------------

    event EscrowCreated(
        uint256 indexed escrowId,
        uint256 indexed loanId,
        address payer,
        address receiver,
        uint256 totalAmount
    );

    event EscrowFunded(uint256 indexed escrowId, uint256 amount);

    event MilestoneApproved(uint256 indexed escrowId, uint256 indexed milestoneId);

    event MilestoneReleased(
        uint256 indexed escrowId,
        uint256 indexed milestoneId,
        uint256 amount
    );

    event EscrowResolved(uint256 indexed escrowId, bool success);

    event EscrowCancelled(uint256 indexed escrowId);

    // -------------------------------------------------
    // CONSTRUCTOR
    // -------------------------------------------------

    constructor(address admin) {
        require(admin != address(0), "ZERO_ADMIN");

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    // -------------------------------------------------
    // VAULT SET
    // -------------------------------------------------

    function setVault(address vaultAddr)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(vaultAddr != address(0), "ZERO");

        if (vaultAddress != address(0)) {
            _revokeRole(VAULT_ROLE, vaultAddress);
        }

        vaultAddress = vaultAddr;
        vault = IReputationVault(vaultAddr);

        _grantRole(VAULT_ROLE, vaultAddr);
    }

    // -------------------------------------------------
    // CREATE
    // -------------------------------------------------

    function create(
        address payer,
        address receiver,
        bytes32 requestId,
        uint256 loanId,
        uint256[] calldata amounts
    )
        external
        onlyRole(VAULT_ROLE)
        whenNotPaused
        returns (uint256)
    {
        require(!usedRequestIds[requestId], "USED");
        require(payer != address(0) && receiver != address(0), "ZERO_ADDR");
        require(amounts.length > 0, "NO_MILESTONES");

        uint256 id = escrowCounter++;
        uint256 total;

        for (uint256 i; i < amounts.length; i++) {
            require(amounts[i] > 0, "ZERO_AMOUNT");

            milestones[id][i] = Milestone({
                amount: amounts[i],
                approved: false,
                released: false,
                releasedAt: 0
            });

            total += amounts[i];
        }

        escrows[id] = Escrow({
            payer: payer,
            receiver: receiver,
            totalAmount: total,
            releasedAmount: 0,
            requestId: requestId,
            loanId: loanId,
            funded: false,
            resolved: false,
            cancelled: false,
            success: false,
            milestoneCount: amounts.length,
            createdAt: block.timestamp,
            resolvedAt: 0
        });

        usedRequestIds[requestId] = true;
        requestToEscrow[requestId] = id;

        emit EscrowCreated(id, loanId, payer, receiver, total);

        return id;
    }

    // -------------------------------------------------
    // FUND
    // -------------------------------------------------

    function fund(uint256 escrowId)
        external
        payable
        nonReentrant
        whenNotPaused
    {
        Escrow storage e = escrows[escrowId];

        require(!e.funded, "FUNDED");
        require(!e.resolved, "RESOLVED");
        require(msg.sender == e.payer, "NOT_PAYER");
        require(msg.value == e.totalAmount, "BAD_AMOUNT");

        e.funded = true;

        emit EscrowFunded(escrowId, msg.value);
    }

    // -------------------------------------------------
    // MILESTONE
    // -------------------------------------------------

    function approveMilestone(uint256 escrowId, uint256 milestoneId)
        external
        onlyRole(RESOLVER_ROLE)
    {
        Escrow storage e = escrows[escrowId];

        require(e.funded && !e.resolved, "BAD_STATE");
        require(milestoneId < e.milestoneCount, "INVALID");

        Milestone storage m = milestones[escrowId][milestoneId];

        require(!m.approved, "APPROVED");

        m.approved = true;

        emit MilestoneApproved(escrowId, milestoneId);
    }

    function releaseMilestone(uint256 escrowId, uint256 milestoneId)
        external
        nonReentrant
        whenNotPaused
    {
        Escrow storage e = escrows[escrowId];

        require(e.funded && !e.resolved, "BAD_STATE");
        require(milestoneId < e.milestoneCount, "INVALID");

        Milestone storage m = milestones[escrowId][milestoneId];

        require(m.approved && !m.released, "BAD_MILESTONE");

        m.released = true;
        m.releasedAt = block.timestamp;

        e.releasedAmount += m.amount;

        (bool sent,) = e.receiver.call{value: m.amount}("");
        require(sent, "TRANSFER_FAIL");

        emit MilestoneReleased(escrowId, milestoneId, m.amount);

        if (e.releasedAmount == e.totalAmount) {
            _resolveEscrow(escrowId, true);
        }
    }

    // -------------------------------------------------
    // FAIL
    // -------------------------------------------------

    function failEscrow(uint256 escrowId)
        external
        onlyRole(RESOLVER_ROLE)
    {
        Escrow storage e = escrows[escrowId];

        require(e.funded && !e.resolved, "BAD_STATE");

        uint256 remaining = e.totalAmount - e.releasedAmount;

        e.cancelled = true;

        if (remaining > 0) {
            (bool sent,) = e.payer.call{value: remaining}("");
            require(sent, "REFUND_FAIL");
        }

        _resolveEscrow(escrowId, false);
    }

    // -------------------------------------------------
    // INTERNAL
    // -------------------------------------------------

    function _resolveEscrow(uint256 escrowId, bool success) internal {
        Escrow storage e = escrows[escrowId];

        require(!e.resolved, "RESOLVED");

        e.resolved = true;
        e.success = success;
        e.resolvedAt = block.timestamp;

        vault.onEscrowResolved(e.loanId, escrowId, success, e.releasedAmount);

        emit EscrowResolved(escrowId, success);
    }

    // -------------------------------------------------
    // VIEWS
    // -------------------------------------------------

    function getMilestone(uint256 escrowId, uint256 milestoneId)
        external
        view
        returns (uint256, bool, bool, uint256)
    {
        Milestone memory m = milestones[escrowId][milestoneId];

        return (m.amount, m.approved, m.released, m.releasedAt);
    }

    function remainingAmount(uint256 escrowId)
        external
        view
        returns (uint256)
    {
        Escrow memory e = escrows[escrowId];
        return e.totalAmount - e.releasedAmount;
    }

    receive() external payable {}
}