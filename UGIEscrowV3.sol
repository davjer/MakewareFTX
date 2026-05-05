// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IReputationVaultV5 {
    function onEscrowResolved(
        uint256 loanId,
        uint256 escrowId,
        bool success,
        uint256 releasedAmount
    ) external;
}

contract UGIEscrowV3 is AccessControl, ReentrancyGuard {

    bytes32 public constant RESOLVER_ROLE = keccak256("RESOLVER_ROLE");
    bytes32 public constant VAULT_ROLE = keccak256("VAULT_ROLE");

    struct Milestone {
        uint256 amount;
        bool approved;
        bool released;
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

        uint256 milestoneCount;
    }

    mapping(uint256 => Escrow) public escrows;
    mapping(uint256 => mapping(uint256 => Milestone)) public milestones;

    mapping(bytes32 => uint256) public requestToEscrow;
    mapping(bytes32 => bool) public usedRequestIds;

    uint256 public escrowCounter;

    IReputationVaultV5 public vault;

    event EscrowCreated(uint256 indexed id, address payer, address receiver);
    event EscrowFunded(uint256 indexed id, uint256 amount);
    event MilestoneApproved(uint256 indexed id, uint256 milestoneId);
    event MilestoneReleased(uint256 indexed id, uint256 milestoneId, uint256 amount);
    event EscrowResolved(uint256 indexed id, bool success);

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function setVault(address vaultAddress)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(vaultAddress != address(0), "ZERO");
        vault = IReputationVaultV5(vaultAddress);
        _grantRole(VAULT_ROLE, vaultAddress);
    }

    function setResolver(address resolver)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(resolver != address(0), "ZERO");
        _grantRole(RESOLVER_ROLE, resolver);
    }

    function create(
        address payer,
        address receiver,
        bytes32 requestId,
        uint256 loanId,
        uint256[] calldata amounts
    )
        external
        onlyRole(VAULT_ROLE)
        returns (uint256)
    {
        require(!usedRequestIds[requestId], "USED");
        require(payer != address(0) && receiver != address(0), "ADDR");
        require(amounts.length > 0, "MILESTONES");

        uint256 id = escrowCounter++;
        uint256 total;

        for (uint256 i = 0; i < amounts.length; i++) {
            require(amounts[i] > 0, "ZERO");

            milestones[id][i] = Milestone({
                amount: amounts[i],
                approved: false,
                released: false
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
            milestoneCount: amounts.length
        });

        usedRequestIds[requestId] = true;
        requestToEscrow[requestId] = id;

        emit EscrowCreated(id, payer, receiver);
        return id;
    }

    function fund(uint256 id)
        external
        payable
        nonReentrant
    {
        Escrow storage e = escrows[id];

        require(!e.funded, "FUNDED");
        require(!e.resolved, "RESOLVED");
        require(msg.sender == e.payer, "PAYER");
        require(msg.value == e.totalAmount, "AMOUNT");

        e.funded = true;

        emit EscrowFunded(id, msg.value);
    }

    function approveMilestone(uint256 id, uint256 milestoneId)
        external
        onlyRole(RESOLVER_ROLE)
    {
        Escrow storage e = escrows[id];

        require(e.funded, "NOT_FUNDED");
        require(!e.resolved, "RESOLVED");
        require(milestoneId < e.milestoneCount, "INVALID");

        Milestone storage m = milestones[id][milestoneId];
        require(!m.approved, "APPROVED");

        m.approved = true;

        emit MilestoneApproved(id, milestoneId);
    }

    function releaseMilestone(uint256 id, uint256 milestoneId)
        external
        nonReentrant
    {
        Escrow storage e = escrows[id];

        require(e.funded, "NOT_FUNDED");
        require(!e.resolved, "RESOLVED");
        require(milestoneId < e.milestoneCount, "INVALID");

        Milestone storage m = milestones[id][milestoneId];

        require(m.approved, "NOT_APPROVED");
        require(!m.released, "RELEASED");

        m.released = true;
        e.releasedAmount += m.amount;

        (bool sent,) = e.receiver.call{value: m.amount}("");
        require(sent, "FAIL");

        emit MilestoneReleased(id, milestoneId, m.amount);

        if (e.releasedAmount == e.totalAmount) {
            e.resolved = true;

            vault.onEscrowResolved(
                e.loanId,
                id,
                true,
                e.releasedAmount
            );

            emit EscrowResolved(id, true);
        }
    }

    function failEscrow(uint256 id)
        external
        nonReentrant
        onlyRole(RESOLVER_ROLE)
    {
        Escrow storage e = escrows[id];

        require(e.funded, "NOT_FUNDED");
        require(!e.resolved, "RESOLVED");

        e.resolved = true;

        uint256 remaining = e.totalAmount - e.releasedAmount;

        if (remaining > 0) {
            (bool sent,) = e.payer.call{value: remaining}("");
            require(sent, "REFUND_FAIL");
        }

        vault.onEscrowResolved(
            e.loanId,
            id,
            false,
            e.releasedAmount
        );

        emit EscrowResolved(id, false);
    }

    receive() external payable {}
}