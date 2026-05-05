// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import "forge-std/Test.sol";

import "../src/ReputationVaultV4.sol";
import "../src/UGIOracleV3.sol";
import "../src/UGIEscrowV2.sol";

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract UGIProtocolV4Test is Test {
    using ECDSA for bytes32;

    ReputationVaultV4 vault;
    UGIOracleV3 oracle;
    UGIEscrowV2 escrow;

    address admin = address(1);
    address user = address(2);
    address signer = address(4);

    uint256 signerPk = 0xA11CE;

    function setUp() public {
        vm.startPrank(admin);

        escrow = new UGIEscrowV2(admin);

        oracle = new UGIOracleV3(address(0));

        vault = new ReputationVaultV4(
            address(oracle),
            address(escrow)
        );

        oracle.setSigner(signer);

        vm.stopPrank();

        vm.deal(user, 10 ether);
    }

    function _sign(UGIOracleV3.Request memory req)
        internal
        view
        returns (bytes memory)
    {
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256(
                    "Request(address executor,bytes32 requestId,bytes32 payloadHash,uint256 deadline,uint256 nonce)"
                ),
                req.executor,
                req.requestId,
                req.payloadHash,
                req.deadline,
                req.nonce
            )
        );

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                oracle.DOMAIN_SEPARATOR(),
                structHash
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, digest);

        return abi.encodePacked(r, s, v);
    }

    function testBorrowFlow() public {

        vm.prank(user);
        vault.deposit{value: 5 ether}();

        bytes32 requestId = keccak256("loan1");

        UGIOracleV3.Request memory req = UGIOracleV3.Request({
            executor: address(vault),
            requestId: requestId,
            payloadHash: keccak256(
                abi.encode(uint8(1), 1 ether)
            ),
            deadline: block.timestamp + 1000,
            nonce: 0
        });

        bytes memory sig = _sign(req);

        vm.prank(user);
        vault.borrow(1, 1 ether, 1 days, req, sig);

        assertTrue(true);
    }
}