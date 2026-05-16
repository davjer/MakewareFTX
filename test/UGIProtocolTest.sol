// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import "forge-std/Test.sol";
import "forge-std/StdInvariant.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

// ----------------------------
// V1 CORE CONTRACTS
// ----------------------------

import "../contracts/v1/ReputationVault.sol";
import "../contracts/v1/UGIOracle.sol";
import "../contracts/v1/UGIEscrow.sol";
import "../contracts/v1/LiquidityPool.sol";
import "../contracts/v1/RiskInterestEngine.sol";
import "../contracts/v1/UGINFTCore.sol";

// ----------------------------
// HANDLERS
// ----------------------------

import "./invariants/BaseInvariantTest.sol";
import "./invariants/handlers/VaultHandler.sol";
import "./invariants/handlers/PoolHandler.sol";
import "./invariants/handlers/OracleHandler.sol";
import "./invariants/handlers/EscrowHandler.sol";
import "./invariants/handlers/NFTHandler.sol";

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
// INVARIANT ENTRY POINT
// ----------------------------

contract UGIProtocolTest is BaseInvariantTest {
    using ECDSA for bytes32;

    ReputationVault vault;
    UGIOracle oracle;
    UGIEscrow escrow;
    LiquidityPool pool;
    RiskInterestEngine risk;
    UGINFTCore nft;
    MockUSDC token;

    address admin = address(1);
    address borrower = address(2);
    address lp = address(3);

    address signer;
    uint256 signerPk = 0xA11CE;

    VaultHandler vaultHandler;
    PoolHandler poolHandler;
    OracleHandler oracleHandler;
    EscrowHandler escrowHandler;
    NFTHandler nftHandler;

    function setUp() public {
        signer = vm.addr(signerPk);

        vm.startPrank(admin);

        token = new MockUSDC();

        nft = new UGINFTCore(admin);
        escrow = new UGIEscrow(admin);
        oracle = new UGIOracle(address(0));

        oracle.setSigner(signer);

        risk = new RiskInterestEngine(address(nft), admin);
        pool = new LiquidityPool(address(token), admin);

        vault = new ReputationVault(
            address(oracle),
            address(escrow),
            address(pool),
            address(risk),
            address(nft)
        );

        escrow.setVault(address(vault));
        pool.setVault(address(vault));
        nft.setVault(address(vault));

        token.mint(lp, 1_000_000 ether);
        token.mint(borrower, 1_000 ether);

        // ----------------------------
        // HANDLERS
        // ----------------------------

        vaultHandler = new VaultHandler(vault);
        poolHandler = new PoolHandler(pool);
        oracleHandler = new OracleHandler(oracle);
        escrowHandler = new EscrowHandler(escrow);
        nftHandler = new NFTHandler(nft);

        targetContract(address(vaultHandler));
        targetContract(address(poolHandler));
        targetContract(address(oracleHandler));
        targetContract(address(escrowHandler));
        targetContract(address(nftHandler));

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
}