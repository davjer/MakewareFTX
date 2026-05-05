// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IUGIOracleV3 {
    struct Request {
        address executor;
        bytes32 requestId;
        address user;
        bytes payload;
        uint256 deadline;
        uint256 nonce;
    }

    function execute(
        Request calldata req,
        bytes calldata sig
    ) external returns (bool approved, uint256 maxAmount);
}

interface IUGIEscrowV3 {
    function create(
        address payer,
        address receiver,
        bytes32 requestId,
        uint256 loanId,
        uint256[] calldata amounts
    ) external returns (uint256);
}

interface IUGIEscrowCallback {
    function onEscrowResolved(
        uint256 loanId,
        uint256 escrowId,
        bool success,
        uint256 releasedAmount
    ) external;
}

interface ILiquidityPoolV2 {
    function borrow(uint256 amount) external;
    function repay(uint256 amount) external;
}

contract ReputationVaultV6 is ReentrancyGuard, IUGIEscrowCallback {

    IUGIOracleV3 public oracle;
    IUGIEscrowV3 public escrow;
    ILiquidityPoolV2 public pool;

    uint256 public loanCounter;
    uint256 public baseInterestBps = 500;

    uint256 public totalExposure;
    uint256 public totalActiveLoans;

    struct Loan {
        uint256 nftId;
        address borrower;
        uint256 amount;
        uint256 repayAmount;
        uint256 deadline;
        bool active;
        bytes32 requestId;
        uint256 maxAmount;
        uint256 escrowId;
    }

    mapping(uint256 => Loan) public loans;
    mapping(bytes32 => bool) public usedRequests;

    event BorrowExecuted(
        uint256 indexed loanId,
        address indexed borrower,
        uint256 amount,
        bytes32 requestId,
        uint256 escrowId
    );

    event LoanResolved(uint256 indexed loanId, bool success);
    event Liquidated(uint256 indexed loanId);

    constructor(
        address oracleAddress,
        address escrowAddress,
        address poolAddress
    ) {
        oracle = IUGIOracleV3(oracleAddress);
        escrow = IUGIEscrowV3(escrowAddress);
        pool = ILiquidityPoolV2(poolAddress);
    }

    // ----------------------------
    // BORROW FLOW
    // ----------------------------
    function borrow(
        uint256 nftId,
        uint256 amount,
        uint256 duration,
        IUGIOracleV3.Request calldata req,
        bytes calldata sig,
        uint256[] calldata milestones
    ) external nonReentrant {

        require(req.executor == address(this), "executor");
        require(!usedRequests[req.requestId], "replay");
        require(block.timestamp <= req.deadline, "expired");

        (bool approved, uint256 maxAmount) =
            oracle.execute(req, sig);

        require(approved, "reject");
        require(amount <= maxAmount, "cap");

        usedRequests[req.requestId] = true;

        uint256 loanId = loanCounter++;

       // uint256 interest = (amount * baseInterestBps) / 10000;

uint256 aprBps = riskEngine.getAPR(nftId);
uint256 interest = (amount * aprBps) / 10000;

        uint256 repayAmount = amount + interest;

        loans[loanId] = Loan({
            nftId: nftId,
            borrower: msg.sender,
            amount: amount,
            repayAmount: repayAmount,
            deadline: block.timestamp + duration,
            active: true,
            requestId: req.requestId,
            maxAmount: maxAmount,
            escrowId: 0
        });

        uint256 escrowId = escrow.create(
            msg.sender,
            msg.sender,
            req.requestId,
            loanId,
            milestones
        );

        loans[loanId].escrowId = escrowId;

        totalExposure += amount;
        totalActiveLoans += 1;

        pool.borrow(amount);

        (bool ok,) = msg.sender.call{value: amount}("");
        require(ok, "transfer fail");

        emit BorrowExecuted(
            loanId,
            msg.sender,
            amount,
            req.requestId,
            escrowId
        );
    }

    // ----------------------------
    // REPAY FLOW
    // ----------------------------
    function repay(uint256 loanId) external payable {
        Loan storage l = loans[loanId];

        require(l.active, "inactive");
        require(msg.value >= l.repayAmount, "insufficient");

        l.active = false;

        totalExposure -= l.amount;
        totalActiveLoans -= 1;

        pool.repay(msg.value);

        emit LoanResolved(loanId, true);
    }

    // ----------------------------
    // LIQUIDATION
    // ----------------------------
    function liquidate(uint256 loanId) external {
        Loan storage l = loans[loanId];

        require(l.active, "inactive");
        require(block.timestamp > l.deadline, "not due");

        l.active = false;

        totalExposure -= l.amount;
        totalActiveLoans -= 1;

        emit Liquidated(loanId);
    }

    // ----------------------------
    // ESCROW CALLBACK
    // ----------------------------
    function onEscrowResolved(
        uint256 loanId,
        uint256 escrowId,
        bool success,
        uint256 releasedAmount
    ) external override {
        require(msg.sender == address(escrow), "escrow");

        Loan storage l = loans[loanId];

        l.active = false;

        if (success) {
            totalExposure -= releasedAmount;
        } else {
            totalExposure -= l.amount;
        }

        totalActiveLoans -= 1;

        emit LoanResolved(loanId, success);
    }

    receive() external payable {}
}