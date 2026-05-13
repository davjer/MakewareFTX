// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

// ----------------------------
// V7 CORE CONTRACTS
// ----------------------------

import "../src/ReputationVaultV7.sol";
import "../src/UGIOracleV4.sol";
import "../src/UGIEscrowV4.sol";
import "../src/LiquidityPoolV3.sol";
import "../src/RiskInterestEngineV2.sol";
import "../src/UGINFTCoreV6.sol";

// ----------------------------
// MOCK TOKEN
// ----------------------------

contract MockUSDC is ERC20 {
    constructor() ERC20("Mock USDC", "mUSDC") {
        _mint(msg.sender, 10_000_000 ether);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}


// ----------------------------
// MAIN TEST
// ----------------------------

contract UGIProtocolV7Test is Test {
    using ECDSA for bytes32;

    // ----------------------------
    // CORE SYSTEM
    // ----------------------------

    ReputationVaultV7 vault;
    UGIOracleV4 oracle;
    UGIEscrowV4 escrow;
    LiquidityPoolV3 pool;
    RiskInterestEngineV2 risk;
    UGINFTCoreV6 nft;
    MockUSDC token;

    // ----------------------------
    // ACTORS
    // ----------------------------

    address admin = address(1);
    address borrower = address(2);
    address lp = address(3);

    address signer;
    uint256 signerPk = 0xA11CE;

    // ----------------------------
    // SETUP
    // ----------------------------

    function setUp() public {
        signer = vm.addr(signerPk);

        vm.startPrank(admin);

        // TOKEN
        token = new MockUSDC();

        // NFT
        nft = new UGINFTCoreV6(admin);

        // ESCROW
        escrow = new UGIEscrowV4(admin);

        // ORACLE
        oracle = new UGIOracleV4(address(0));
        oracle.setSigner(signer);

        // RISK ENGINE
        risk = new RiskInterestEngineV2(address(nft), admin);

        // POOL
        pool = new LiquidityPoolV3(address(token), admin);

        // VAULT (CORE)
        vault = new ReputationVaultV7(
            address(oracle),
            address(escrow),
            address(pool),
            address(risk),
            address(nft)
        );

        // WIRING
        escrow.setVault(address(vault));
        pool.setVault(address(vault));
        nft.setVault(address(vault));

        // FUNDING
        token.mint(lp, 1_000_000 ether);
        token.mint(borrower, 1_000 ether);

        vm.stopPrank();
    }

    // ----------------------------
    // HELPERS
    // ----------------------------

    function _depositLiquidity() internal {
        vm.startPrank(lp);

        token.approve(address(pool), type(uint256).max);
        pool.deposit(500_000 ether);

        vm.stopPrank();
    }

    function _mintNFT() internal returns (uint256) {
        vm.deal(borrower, 10 ether);

        vm.prank(borrower);
        return nft.mint{value: 0.01 ether}(borrower, "ipfs://test");
    }

    // ----------------------------
    // TEST: BORROW FLOW
    // ----------------------------

    function testBorrowFlow() public {
        _depositLiquidity();
        uint256 nftId = _mintNFT();

        bytes32 requestId = keccak256("loan-v7");

        UGIOracleV4.Payload memory p = UGIOracleV4.Payload({
            amount: 1000 ether,
            tier: 1,
            nftId: bytes32(nftId)
        });

        UGIOracleV4.Request memory req = UGIOracleV4.Request({
            executor: address(vault),
            requestId: requestId,
            user: borrower,
            payload: abi.encode(p),
            deadline: block.timestamp + 1 days,
            nonce: 0
        });

        bytes memory sig = _sign(req, p);

        uint256[] memory milestones = new uint256[](2);
        milestones[0] = 500 ether;
        milestones[1] = 500 ether;

        vm.prank(borrower);

        vault.borrow(
            nftId,
            1000 ether,
            30 days,
            req,
            sig,
            milestones
        );

        assertEq(vault.totalExposure(), 1000 ether);
        assertEq(vault.totalActiveLoans(), 1);
        assertEq(pool.totalBorrowed(), 1000 ether);
    }

    // ----------------------------
    // TEST: REPAY FLOW
    // ----------------------------

    function testRepayFlow() public {
        _depositLiquidity();
        uint256 nftId = _mintNFT();

        bytes32 requestId = keccak256("repay-v7");

        UGIOracleV4.Payload memory p = UGIOracleV4.Payload({
            amount: 1000 ether,
            tier: 1,
            nftId: bytes32(nftId)
        });

        UGIOracleV4.Request memory req = UGIOracleV4.Request({
            executor: address(vault),
            requestId: requestId,
            user: borrower,
            payload: abi.encode(p),
            deadline: block.timestamp + 1 days,
            nonce: 0
        });

        bytes memory sig = _sign(req, p);

        uint256[] memory milestones = new uint256[](1);
        milestones[0] = 1000 ether;

        vm.prank(borrower);
        vault.borrow(nftId, 1000 ether, 30 days, req, sig, milestones);

        ReputationVaultV7.Loan memory loan = vault.loans(0);

        vm.deal(borrower, 100 ether);

        vm.prank(borrower);
        vault.repay{value: loan.repayAmount}(0);

        assertEq(vault.totalActiveLoans(), 0);
        assertEq(vault.totalExposure(), 0);
    }

    // ----------------------------
    // TEST: LIQUIDATION
    // ----------------------------

    function testLiquidation() public {
        _depositLiquidity();
        uint256 nftId = _mintNFT();

        bytes32 requestId = keccak256("liq-v7");

        UGIOracleV4.Payload memory p = UGIOracleV4.Payload({
            amount: 500 ether,
            tier: 0,
            nftId: bytes32(nftId)
        });

        UGIOracleV4.Request memory req = UGIOracleV4.Request({
            executor: address(vault),
            requestId: requestId,
            user: borrower,
            payload: abi.encode(p),
            deadline: block.timestamp + 1 days,
            nonce: 0
        });

        bytes memory sig = _sign(req, p);

        uint256[] memory milestones = new uint256[](1);
        milestones[0] = 500 ether;

        vm.prank(borrower);
        vault.borrow(nftId, 500 ether, 1 days, req, sig, milestones);

        vm.warp(block.timestamp + 2 days);

        vm.prank(admin);
        vault.grantRole(vault.LIQUIDATOR_ROLE(), admin);

        vm.prank(admin);
        vault.liquidate(0);

        assertGt(vault.totalLiquidated(), 0);
        assertEq(vault.totalActiveLoans(), 0);
    }

    // ----------------------------
    // EIP-712 SIGNING (V7 STYLE)
    // ----------------------------

    function _sign(
        UGIOracleV4.Request memory req,
        UGIOracleV4.Payload memory p
    ) internal view returns (bytes memory) {
        bytes32 payloadHash = keccak256(
            abi.encode(
                keccak256("Payload(uint256 amount,uint8 tier,bytes32 nftId)"),
                p.amount,
                p.tier,
                p.nftId
            )
        );

        bytes32 structHash = keccak256(
            abi.encode(
                keccak256(
                    "Request(address executor,bytes32 requestId,address user,bytes payload,uint256 deadline,uint256 nonce)"
                ),
                req.executor,
                req.requestId,
                req.user,
                payloadHash,
                req.deadline,
                req.nonce
            )
        );

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                oracle.domainSeparator(),
                structHash
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, digest);

        return abi.encodePacked(r, s, v);
    }
}