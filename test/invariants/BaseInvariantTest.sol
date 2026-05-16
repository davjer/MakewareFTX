// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import "forge-std/Test.sol";
import "forge-std/StdInvariant.sol";

// ----------------------------
// CORE CONTRACTS
// ----------------------------

import "../../contracts/v1/ReputationVault.sol";
import "../../contracts/v1/UGINFTCore.sol";
import "../../contracts/v1/LiquidityPool.sol";
import "../../contracts/v1/UGIOracle.sol";
import "../../contracts/v1/UGIEscrow.sol";

// ----------------------------
// HANDLERS
// ----------------------------

import "./handlers/VaultHandler.sol";
import "./handlers/PoolHandler.sol";
import "./handlers/OracleHandler.sol";
import "./handlers/EscrowHandler.sol";
import "./handlers/NFTHandler.sol";

contract BaseInvariantTest is StdInvariant, Test {

    ReputationVault public vault;
    UGINFTCore public nft;
    LiquidityPool public pool;
    UGIOracle public oracle;
    UGIEscrow public escrow;

    VaultHandler public vaultHandler;
    PoolHandler public poolHandler;
    OracleHandler public oracleHandler;
    EscrowHandler public escrowHandler;
    NFTHandler public nftHandler;

    address admin = address(1);

    function setUp() public {
        vm.startPrank(admin);

        nft = new UGINFTCore(admin);

        pool = new LiquidityPool(address(0), admin);

        oracle = new UGIOracle(address(nft), admin);

        escrow = new UGIEscrow(admin);

        vault = new ReputationVault(
            address(oracle),
            address(escrow),
            address(pool)
        );

        pool.setVault(address(vault));
        escrow.setVault(address(vault));
        nft.setVault(address(vault));

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
}