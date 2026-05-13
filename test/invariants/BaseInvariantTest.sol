// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import "forge-std/Test.sol";
import "forge-std/StdInvariant.sol";

import "../../src/ReputationVaultV7.sol";
//import "../../src/UGINFTCoreV6.sol";
import "../../src/LiquidityPoolV3.sol";
//import "../../src/UGIOracleV4.sol";
//import "../../src/UGIEscrowV4.sol";

import "./handlers/VaultHandler.sol";
import "./handlers/PoolHandler.sol";
import "./handlers/OracleHandler.sol";
import "./handlers/EscrowHandler.sol";
import "./handlers/NFTHandler.sol";

contract BaseInvariantTest is StdInvariant, Test {

    ReputationVaultV7 public vault;
    UGINFTCoreV6 public nft;
    LiquidityPoolV3 public pool;
    UGIOracleV4 public oracle;
    UGIEscrowV4 public escrow;

    VaultHandler public vaultHandler;
    PoolHandler public poolHandler;
    OracleHandler public oracleHandler;
    EscrowHandler public escrowHandler;
    NFTHandler public nftHandler;

    address admin = address(1);

    function setUp() public {
        vm.startPrank(admin);

        nft = new UGINFTCoreV6(admin);
        oracle = new UGIOracleV3(address(0));
        escrow = new UGIEscrowV4(admin);
        pool = new LiquidityPoolV3(address(0), admin);

        vault = new ReputationVaultV7(
            address(oracle),
            address(escrow),
            address(pool)
        );

        // HANDLERS
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