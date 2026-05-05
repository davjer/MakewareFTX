 // SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract LiquidityPoolV1 is AccessControl, ReentrancyGuard {

    bytes32 public constant VAULT_ROLE = keccak256("VAULT_ROLE");

    IERC20 public immutable asset;

    uint256 public totalAssets;
    uint256 public totalShares;

    mapping(address => uint256) public shares;

    event Deposit(address indexed user, uint256 amount, uint256 sharesMinted);
    event Withdraw(address indexed user, uint256 amount, uint256 sharesBurned);
    event Borrow(address indexed vault, uint256 amount);
    event Repay(address indexed vault, uint256 amount);

    constructor(address _asset, address admin) {
        require(_asset != address(0), "ZERO_ASSET");
        asset = IERC20(_asset);

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function deposit(uint256 amount)
        external
        nonReentrant
        returns (uint256 mintedShares)
    {
        require(amount > 0, "ZERO");

        asset.transferFrom(msg.sender, address(this), amount);

        if (totalShares == 0) {
            mintedShares = amount;
        } else {
            mintedShares = (amount * totalShares) / totalAssets;
        }

        shares[msg.sender] += mintedShares;
        totalShares += mintedShares;
        totalAssets += amount;

        emit Deposit(msg.sender, amount, mintedShares);
    }

    function withdraw(uint256 shareAmount)
        external
        nonReentrant
        returns (uint256 amount)
    {
        require(shareAmount > 0, "ZERO");
        require(shares[msg.sender] >= shareAmount, "SHARES");

        amount = (shareAmount * totalAssets) / totalShares;

        shares[msg.sender] -= shareAmount;
        totalShares -= shareAmount;
        totalAssets -= amount;

        asset.transfer(msg.sender, amount);

        emit Withdraw(msg.sender, amount, shareAmount);
    }

    function borrow(uint256 amount)
        external
        onlyRole(VAULT_ROLE)
    {
        require(amount <= availableLiquidity(), "LIQ");

        totalAssets -= amount;

        asset.transfer(msg.sender, amount);

        emit Borrow(msg.sender, amount);
    }

    function repay(uint256 amount)
        external
        onlyRole(VAULT_ROLE)
    {
        require(amount > 0, "ZERO");

        asset.transferFrom(msg.sender, address(this), amount);

        totalAssets += amount;

        emit Repay(msg.sender, amount);
    }

    function availableLiquidity() public view returns (uint256) {
        return totalAssets;
    }

    function shareValue() external view returns (uint256) {
        if (totalShares == 0) return 0;
        return (totalAssets * 1e18) / totalShares;
    }

    function userBalance(address user) external view returns (uint256) {
        if (totalShares == 0) return 0;
        return (shares[user] * totalAssets) / totalShares;
    }
}