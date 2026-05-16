```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

import "../interfaces/ILiquidityPool.sol";
import "../interfaces/IReputationVault.sol";

contract LiquidityPool is
    AccessControl,
    ReentrancyGuard,
    Pausable,
    ILiquidityPool
{
    bytes32 public constant VAULT_ROLE =
        keccak256("VAULT_ROLE");

    IERC20 public immutable asset;
    uint8 public immutable assetDecimals;

    IReputationVault public vault;
    address public vaultAddress;

    uint256 public totalAssets;
    uint256 public totalShares;
    uint256 public totalBorrowed;
    uint256 public totalAvailable;
    uint256 public totalDeposited;
    uint256 public totalWithdrawn;
    uint256 public totalInterestCollected;

    uint256 public reserveBps = 1000;
    uint256 public constant MAX_BPS = 10000;

    mapping(address => uint256) public shares;

    event Deposit(address indexed user, uint256 amount, uint256 sharesMinted);
    event Withdraw(address indexed user, uint256 amount, uint256 sharesBurned);
    event Borrow(address indexed vault, uint256 amount, uint256 exposure);
    event Repay(address indexed vault, uint256 amount);
    event VaultUpdated(address indexed vault);
    event ReserveUpdated(uint256 reserveBps);

    constructor(address assetAddress, address admin) {
        require(assetAddress != address(0), "ZERO_ASSET");
        require(admin != address(0), "ZERO_ADMIN");

        asset = IERC20(assetAddress);
        assetDecimals = IERC20Metadata(assetAddress).decimals();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function setVault(address newVault)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(newVault != address(0), "ZERO");

        if (vaultAddress != address(0)) {
            _revokeRole(VAULT_ROLE, vaultAddress);
        }

        vaultAddress = newVault;
        vault = IReputationVault(newVault);

        _grantRole(VAULT_ROLE, newVault);

        emit VaultUpdated(newVault);
    }

    function setReserveBps(uint256 bps)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(bps <= 3000, "TOO_HIGH");
        reserveBps = bps;

        emit ReserveUpdated(bps);
    }

    function pause()
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _pause();
    }

    function unpause()
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _unpause();
    }

    function deposit(uint256 amount)
        external
        nonReentrant
        whenNotPaused
        returns (uint256 mintedShares)
    {
        require(amount > 0, "ZERO");

        uint256 beforeBal = asset.balanceOf(address(this));

        asset.transferFrom(msg.sender, address(this), amount);

        uint256 received =
            asset.balanceOf(address(this)) - beforeBal;

        require(received > 0, "NO_RECEIVED");

        if (totalShares == 0) {
            mintedShares = received;
        } else {
            mintedShares =
                (received * totalShares) / totalAssets;
        }

        require(mintedShares > 0, "ZERO_SHARES");

        shares[msg.sender] += mintedShares;

        totalShares += mintedShares;
        totalAssets += received;
        totalAvailable += received;
        totalDeposited += received;

        emit Deposit(msg.sender, received, mintedShares);
    }

    function withdraw(uint256 shareAmount)
        external
        nonReentrant
        whenNotPaused
        returns (uint256 amount)
    {
        require(shareAmount > 0, "ZERO");
        require(
            shares[msg.sender] >= shareAmount,
            "INSUFFICIENT_SHARES"
        );

        amount =
            (shareAmount * totalAssets) / totalShares;

        require(
            amount <= withdrawableLiquidity(),
            "LOCKED_LIQ"
        );

        shares[msg.sender] -= shareAmount;

        totalShares -= shareAmount;
        totalAssets -= amount;
        totalAvailable -= amount;
        totalWithdrawn += amount;

        asset.transfer(msg.sender, amount);

        emit Withdraw(msg.sender, amount, shareAmount);
    }

    function borrow(uint256 amount)
        external
        onlyRole(VAULT_ROLE)
        nonReentrant
        whenNotPaused
    {
        require(amount > 0, "ZERO");
        require(
            amount <= withdrawableLiquidity(),
            "INSUFFICIENT_LIQ"
        );

        totalAvailable -= amount;
        totalBorrowed += amount;

        asset.transfer(msg.sender, amount);

        vault.onLiquidityBorrow(amount);

        emit Borrow(msg.sender, amount, totalBorrowed);
    }

    function repay(uint256 principal, uint256 interest)
        external
        onlyRole(VAULT_ROLE)
        nonReentrant
        whenNotPaused
    {
        require(principal > 0, "ZERO");

        uint256 total = principal + interest;

        asset.transferFrom(msg.sender, address(this), total);

        require(
            totalBorrowed >= principal,
            "OVERPAY"
        );

        totalBorrowed -= principal;
        totalAvailable += total;
        totalAssets += interest;
        totalInterestCollected += interest;

        vault.onLiquidityRepay(total);

        emit Repay(msg.sender, total);
    }

    function reservedLiquidity()
        public
        view
        returns (uint256)
    {
        return (totalAssets * reserveBps) / MAX_BPS;
    }

    function withdrawableLiquidity()
        public
        view
        returns (uint256)
    {
        uint256 reserve = reservedLiquidity();

        if (totalAvailable <= reserve) return 0;

        return totalAvailable - reserve;
    }

    function shareValue()
        public
        view
        returns (uint256)
    {
        if (totalShares == 0) return 0;

        return (totalAssets * 1e18) / totalShares;
    }

    function userBalance(address user)
        external
        view
        returns (uint256)
    {
        if (totalShares == 0) return 0;

        return (shares[user] * totalAssets) / totalShares;
    }

    function utilizationBps()
        external
        view
        returns (uint256)
    {
        if (totalAssets == 0) return 0;

        return (totalBorrowed * MAX_BPS) / totalAssets;
    }

    function availableLiquidity()
        external
        view
        returns (uint256)
    {
        return totalAvailable;
    }

    function exposure()
        external
        view
        returns (uint256)
    {
        return totalBorrowed;
    }
}