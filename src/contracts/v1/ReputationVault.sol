// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

import "../interfaces/IUGINFTCore.sol";
import "../interfaces/IUGIOracle.sol";
import "../interfaces/IUGIEscrow.sol";
import "../interfaces/ILiquidityPool.sol";
import "../interfaces/IRiskInterestEngine.sol";
import "../interfaces/IReputationVault.sol";
import "../interfaces/IUGIEscrowCallback.sol";

contract ReputationVault is
    AccessControl,
    ReentrancyGuard,
    Pausable,
    IReputationVault
{
    bytes32 public constant LIQUIDATOR_ROLE =
        keccak256("LIQUIDATOR_ROLE");

    bytes32 public constant RESOLVER_ROLE =
        keccak256("RESOLVER_ROLE");

    IUGIOracle public oracle;

    IUGIEscrow public escrow;

    ILiquidityPool public pool;

    IRiskInterestEngine public riskEngine;

    IUGINFTCore public nft;

    uint256 public loanCounter;

    uint256 public totalExposure;

    uint256 public totalBorrowed;

    uint256 public totalRepaid;

    uint256 public totalLiquidated;

    uint256 public totalActiveLoans;

    uint256 public maxLoanDuration =
        90 days;

    uint256 public minLoanDuration =
        1 days;

    struct Loan {
        uint256 nftId;
        address borrower;
        uint256 amount;
        uint256 repayAmount;
        uint256 aprBps;
        uint256 deadline;
        bool active;
        bytes32 requestId;
        uint256 maxAmount;
        uint256 escrowId;
        uint256 createdAt;
        bool repaid;
        bool liquidated;
        bool escrowResolved;
    }

    mapping(uint256 => Loan)
        public loans;

    mapping(bytes32 => bool)
        public usedRequests;

    mapping(uint256 => uint256[])
        public nftLoans;

    mapping(address => uint256[])
        public borrowerLoans;

    event BorrowExecuted(
        uint256 indexed loanId,
        uint256 indexed nftId,
        address indexed borrower,
        uint256 amount,
        uint256 repayAmount,
        uint256 aprBps,
        bytes32 requestId,
        uint256 escrowId
    );

    event LoanRepaid(
        uint256 indexed loanId,
        uint256 amount
    );

    event LoanLiquidated(
        uint256 indexed loanId
    );

    event EscrowResolved(
        uint256 indexed loanId,
        uint256 indexed escrowId,
        bool success,
        uint256 releasedAmount
    );

    constructor(
        address oracleAddress,
        address escrowAddress,
        address poolAddress,
        address riskAddress,
        address nftAddress
    ) {
        oracle =
            IUGIOracle(
                oracleAddress
            );

        escrow =
            IUGIEscrow(
                escrowAddress
            );

        pool =
            ILiquidityPool(
                poolAddress
            );

        riskEngine =
            IRiskInterestEngine(
                riskAddress
            );

        nft =
            IUGINFTCore(
                nftAddress
            );

        _grantRole(
            DEFAULT_ADMIN_ROLE,
            msg.sender
        );
    }

    function pause()
        external
        onlyRole(
            DEFAULT_ADMIN_ROLE
        )
    {
        _pause();
    }

    function unpause()
        external
        onlyRole(
            DEFAULT_ADMIN_ROLE
        )
    {
        _unpause();
    }

    function setDurationLimits(
        uint256 minDuration,
        uint256 maxDuration
    )
        external
        onlyRole(
            DEFAULT_ADMIN_ROLE
        )
    {
        require(
            minDuration <
            maxDuration,
            "INVALID"
        );

        minLoanDuration =
            minDuration;

        maxLoanDuration =
            maxDuration;
    }

    function borrow(
        uint256 nftId,
        uint256 amount,
        uint256 duration,
        IUGIOracle.Request calldata req,
        bytes calldata sig,
        uint256[] calldata milestones
    )
        external
        nonReentrant
        whenNotPaused
    {
        require(
            nft.ownerOf(nftId) ==
            msg.sender,
            "NOT_OWNER"
        );

        require(
            req.executor ==
            address(this),
            "BAD_EXECUTOR"
        );

        require(
            req.user ==
            msg.sender,
            "BAD_USER"
        );

        require(
            !usedRequests[
                req.requestId
            ],
            "REPLAY"
        );

        require(
            duration >=
            minLoanDuration,
            "SHORT"
        );

        require(
            duration <=
            maxLoanDuration,
            "LONG"
        );

        (
            bool approved,
            uint256 maxAmount
        ) = oracle.execute(
                req,
                sig
            );

        require(
            approved,
            "REJECTED"
        );

        require(
            amount <=
            maxAmount,
            "MAX_EXCEEDED"
        );

        usedRequests[
            req.requestId
        ] = true;

        uint256 aprBps =
            riskEngine.getAPR(
                nftId
            );

        uint256 repayAmount =
            amount +
            (
                amount *
                aprBps
            ) /
            10000;

        uint256 loanId =
            loanCounter++;

        loans[loanId] = Loan({
            nftId: nftId,
            borrower: msg.sender,
            amount: amount,
            repayAmount: repayAmount,
            aprBps: aprBps,
            deadline:
                block.timestamp +
                duration,
            active: true,
            requestId:
                req.requestId,
            maxAmount:
                maxAmount,
            escrowId: 0,
            createdAt:
                block.timestamp,
            repaid: false,
            liquidated: false,
            escrowResolved: false
        });

        nftLoans[nftId]
            .push(loanId);

        borrowerLoans[
            msg.sender
        ].push(loanId);

        nft.setExposureLock(
            nftId,
            true
        );

        uint256 escrowId =
            escrow.create(
                address(this),
                msg.sender,
                req.requestId,
                loanId,
                milestones
            );

        loans[loanId]
            .escrowId =
            escrowId;

        totalExposure +=
            amount;

        totalBorrowed +=
            amount;

        totalActiveLoans++;

        pool.borrow(amount);

        (
            bool ok,

        ) = msg.sender.call{
            value: amount
        }("");

        require(
            ok,
            "TRANSFER_FAIL"
        );

        emit BorrowExecuted(
            loanId,
            nftId,
            msg.sender,
            amount,
            repayAmount,
            aprBps,
            req.requestId,
            escrowId
        );
    }

    function repay(
        uint256 loanId
    )
        external
        payable
        nonReentrant
        whenNotPaused
    {
        Loan storage l =
            loans[loanId];

        require(
            l.active,
            "INACTIVE"
        );

        require(
            !l.repaid,
            "REPAID"
        );

        require(
            !l.liquidated,
            "LIQUIDATED"
        );

        require(
            msg.sender ==
            l.borrower,
            "NOT_BORROWER"
        );

        require(
            msg.value >=
            l.repayAmount,
            "INSUFFICIENT"
        );

        l.active = false;

        l.repaid = true;

        totalExposure -=
            l.amount;

        totalRepaid +=
            msg.value;

        totalActiveLoans--;

        nft.setExposureLock(
            l.nftId,
            false
        );

        nft.bindLoanResult(
            l.nftId,
            l.requestId,
            true
        );

        pool.repay(
            msg.value
        );

        emit LoanRepaid(
            loanId,
            msg.value
        );
    }

    function liquidate(
        uint256 loanId
    )
        external
        nonReentrant
        onlyRole(
            LIQUIDATOR_ROLE
        )
    {
        Loan storage l =
            loans[loanId];

        require(
            l.active,
            "INACTIVE"
        );

        require(
            !l.repaid,
            "REPAID"
        );

        require(
            !l.liquidated,
            "DONE"
        );

        require(
            block.timestamp >
            l.deadline,
            "NOT_DUE"
        );

        l.active = false;

        l.liquidated = true;

        totalExposure -=
            l.amount;

        totalLiquidated +=
            l.amount;

        totalActiveLoans--;

        nft.setExposureLock(
            l.nftId,
            false
        );

        nft.bindLoanResult(
            l.nftId,
            l.requestId,
            false
        );

        emit LoanLiquidated(
            loanId
        );
    }

    function onEscrowResolved(
        uint256 loanId,
        uint256 escrowId,
        bool success,
        uint256 releasedAmount
    )
        external
        nonReentrant
    {
        require(
            msg.sender ==
            address(escrow),
            "NOT_ESCROW"
        );

        Loan storage l =
            loans[loanId];

        require(
            l.active,
            "INACTIVE"
        );

        require(
            l.escrowId ==
            escrowId,
            "BAD_ESCROW"
        );

        l.active = false;

        l.escrowResolved =
            true;

        totalActiveLoans--;

        nft.setExposureLock(
            l.nftId,
            false
        );

        if (success) {

            totalExposure -=
                releasedAmount;

            nft.bindLoanResult(
                l.nftId,
                l.requestId,
                true
            );

        } else {

            totalExposure -=
                l.amount;

            nft.bindLoanResult(
                l.nftId,
                l.requestId,
                false
            );
        }

        emit EscrowResolved(
            loanId,
            escrowId,
            success,
            releasedAmount
        );
    }

    function hasActiveExposure(
        uint256 nftId
    )
        external
        view
        returns (bool)
    {
        uint256[] memory ids =
            nftLoans[nftId];

        for (
            uint256 i;
            i < ids.length;
            i++
        ) {
            if (
                loans[
                    ids[i]
                ].active
            ) {
                return true;
            }
        }

        return false;
    }

    receive()
        external
        payable
    {}
}
