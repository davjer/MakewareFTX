// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IUGINFTCoreV2 {
    function getProfile(uint256 id)
        external
        view
        returns (
            uint256 score,
            uint256 backing,
            uint256 valuation,
            uint8 tier
        );

    function updateScore(uint256 id, int256 delta) external;
}

contract ReputationVaultV2 {

    // -----------------------------
    // NFT CORE
    // -----------------------------
    IUGINFTCoreV2 public nft;

    address public admin;

    // -----------------------------
    // LIQUIDITY
    // -----------------------------
    uint256 public totalLiquidity;

    // -----------------------------
    // LOANS
    // -----------------------------
    uint256 public loanCounter;

    enum LoanState {
        ACTIVE,
        REPAID,
        DEFAULTED,
        OVERDUE
    }

    struct Loan {
        uint256 id;
        uint256 nftId;
        address borrower;

        uint256 principal;
        uint256 interest;
        uint256 repayAmount;

        uint256 startTime;
        uint256 deadline;

        LoanState state;
    }

    mapping(uint256 => Loan) public loans;

    // -----------------------------
    // RISK PARAMETERS
    // -----------------------------
    uint256 public constant BASE_RATE_BP = 1200; // 12%
    uint256 public constant LATE_PENALTY_BP = 500;

    // -----------------------------
    // EVENTS
    // -----------------------------
    event Deposited(address indexed from, uint256 amount);
    event Borrowed(uint256 indexed id, uint256 nftId, uint256 amount);
    event Repaid(uint256 indexed id, uint256 amount);
    event Defaulted(uint256 indexed id);

    // -----------------------------
    // INIT
    // -----------------------------
    constructor(address nftAddress) {
        nft = IUGINFTCoreV2(nftAddress);
        admin = msg.sender;
    }

    // =====================================================
    // 💰 LIQUIDITY DEPOSIT
    // =====================================================
    function deposit() external payable {
        require(msg.value > 0, "zero deposit");

        totalLiquidity += msg.value;

        emit Deposited(msg.sender, msg.value);
    }

    // =====================================================
    // 🏦 BORROW LOGIC (CORE SYSTEM)
    // =====================================================
    function borrow(
        uint256 nftId,
        uint256 principal,
        uint256 duration
    ) external {

        require(principal > 0, "invalid amount");
        require(duration >= 1 days, "too short");
        require(totalLiquidity >= principal, "insufficient liquidity");

        // 🔥 RISK ENGINE (from NFT)
        (uint256 score, , , uint8 tier) =
            nft.getProfile(nftId);

        require(score > 20, "low credit score");

        uint256 rate = _getRate(tier);

        uint256 interest =
            (principal * rate) / 10000;

        uint256 repayAmount = principal + interest;

        loans[loanCounter] = Loan({
            id: loanCounter,
            nftId: nftId,
            borrower: msg.sender,
            principal: principal,
            interest: interest,
            repayAmount: repayAmount,
            startTime: block.timestamp,
            deadline: block.timestamp + duration,
            state: LoanState.ACTIVE
        });

        totalLiquidity -= principal;

        payable(msg.sender).transfer(principal);

        emit Borrowed(loanCounter, nftId, principal);

        loanCounter++;
    }

    // =====================================================
    // 💸 REPAYMENT
    // =====================================================
    function repay(uint256 id) external payable {

        Loan storage l = loans[id];

        require(l.state == LoanState.ACTIVE, "inactive");
        require(msg.sender == l.borrower, "not borrower");

        uint256 amountDue = l.repayAmount;

        // late penalty
        if (block.timestamp > l.deadline) {
            amountDue += (l.principal * LATE_PENALTY_BP) / 10000;
        }

        require(msg.value >= amountDue, "insufficient payment");

        l.state = LoanState.REPAID;

        totalLiquidity += amountDue;

        // 🔥 REWARD CREDIT SCORE (via Oracle flow later)
        nft.updateScore(l.nftId, 10);

        emit Repaid(id, amountDue);
    }

    // =====================================================
    // ❌ DEFAULT LOGIC
    // =====================================================
    function markDefault(uint256 id) external {

        Loan storage l = loans[id];

        require(l.state == LoanState.ACTIVE, "not active");
        require(block.timestamp > l.deadline, "not overdue");

        l.state = LoanState.DEFAULTED;

        // 🔥 PENALTY SCORE
        nft.updateScore(l.nftId, -20);

        emit Defaulted(id);
    }

    // =====================================================
    // 📊 RISK ENGINE
    // =====================================================
    function _getRate(uint8 tier)
        internal
        pure
        returns (uint256)
    {
        if (tier == 0) return 2000; // LOW → 20%
        if (tier == 1) return 1500; // BASIC → 15%
        if (tier == 2) return 1000; // TRUSTED → 10%
        return 700;                 // PRIME → 7%
    }

    // =====================================================
    // 🔍 VIEW LOAN
    // =====================================================
    function getLoan(uint256 id)
        external
        view
        returns (Loan memory)
    {
        return loans[id];
    }

    receive() external payable {}
}