// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract LendingPool {
    using SafeERC20 for IERC20;

    uint256 public constant SECONDS_PER_YEAR = 31536000;

    uint256 public constant baseRate = 0.02e18; // 2%
    uint256 public constant slopeLow = 0.1e18; // 10%
    uint256 public constant slopeHigh = 1e18; // 100%
    uint256 public constant kink = 0.8e18; // 80%

    mapping(address => mapping(address => uint256)) public collateral;
    mapping(address => mapping(address => uint256)) public borrowed;
    mapping(address => mapping(address => uint256)) public lastUpdate;

    mapping(address => uint256) public totalSupplied;
    mapping(address => uint256) public totalBorrowed;

    event Supplied(address indexed user, address indexed token, uint256 amount);
    event Withdrawn(address indexed user, address indexed token, uint256 amount);
    event Borrowed(address indexed user, address indexed token, uint256 amount);
    event Repaid(address indexed user, address indexed token, uint256 amount);
    event Liquidated(
        address indexed borrower,
        address indexed liquidator,
        address indexed token,
        uint256 repaid,
        uint256 collateralSeized
    );

    function supply(IERC20 token, uint256 amount) external {
        require(amount > 0, "Zero deposit");
        address tokenAddr = address(token);

        collateral[msg.sender][tokenAddr] += amount;
        totalSupplied[tokenAddr] += amount;

        token.safeTransferFrom(msg.sender, address(this), amount);
        emit Supplied(msg.sender, tokenAddr, amount);
    }

    function withdraw(IERC20 token, uint256 amount) external {
        _accrueInterest(msg.sender, token);
        address tokenAddr = address(token);

        require(amount > 0, "Zero withdrawal");
        require(collateral[msg.sender][tokenAddr] >= amount, "Insufficient collateral");

        collateral[msg.sender][tokenAddr] -= amount;
        totalSupplied[tokenAddr] -= amount;

        token.safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, tokenAddr, amount);
    }

    function borrow(IERC20 token, uint256 amount) external {
        _accrueInterest(msg.sender, token);
        address tokenAddr = address(token);

        require(amount > 0, "Zero borrow");
        require(totalSupplied[tokenAddr] >= amount, "Insufficient pool balance");
        require(borrowed[msg.sender][tokenAddr] + amount <= collateral[msg.sender][tokenAddr] * 50 / 100, "Exceeds LTV");

        borrowed[msg.sender][tokenAddr] += amount;
        totalBorrowed[tokenAddr] += amount;

        token.safeTransfer(msg.sender, amount);
        emit Borrowed(msg.sender, tokenAddr, amount);
    }

    function repay(IERC20 token, uint256 amount) external {
        _accrueInterest(msg.sender, token);
        address tokenAddr = address(token);

        require(amount > 0, "Zero repayment");
        require(borrowed[msg.sender][tokenAddr] >= amount, "Repayment exceeds debt");

        borrowed[msg.sender][tokenAddr] -= amount;
        totalBorrowed[tokenAddr] -= amount;

        token.safeTransferFrom(msg.sender, address(this), amount);
        emit Repaid(msg.sender, tokenAddr, amount);
    }

    function liquidate(IERC20 token, address user, uint256 repayAmount) external {
        _accrueInterest(user, token);
        address tokenAddr = address(token);

        require(repayAmount > 0, "Zero repay");
        require(borrowed[user][tokenAddr] > 0, "No debt");
        require(borrowed[user][tokenAddr] > collateral[user][tokenAddr] * 50 / 100, "Not undercollateralized");

        uint256 collateralToSeize = repayAmount * 110 / 100;
        require(collateral[user][tokenAddr] >= collateralToSeize, "Insufficient collateral");

        borrowed[user][tokenAddr] -= repayAmount;
        totalBorrowed[tokenAddr] -= repayAmount;

        collateral[user][tokenAddr] -= collateralToSeize;
        totalSupplied[tokenAddr] -= collateralToSeize;

        token.safeTransfer(msg.sender, collateralToSeize);
        token.safeTransferFrom(msg.sender, address(this), repayAmount);

        emit Liquidated(user, msg.sender, tokenAddr, repayAmount, collateralToSeize);
    }

    function accruedInterest(address user, address token) public view returns (uint256) {
        uint256 timeElapsed = block.timestamp - lastUpdate[user][token];
        uint256 rate = getBorrowRate(token);
        return (borrowed[user][token] * rate * timeElapsed) / 1e18 / SECONDS_PER_YEAR;
    }

    function _accrueInterest(address user, IERC20 token) internal {
        address tokenAddr = address(token);
        uint256 interest = accruedInterest(user, tokenAddr);
        if (interest > 0) {
            borrowed[user][tokenAddr] += interest;
            totalBorrowed[tokenAddr] += interest;
        }
        lastUpdate[user][tokenAddr] = block.timestamp;
    }

    function getBorrowRate(address token) public view returns (uint256) {
        uint256 util = utilization(token);
        if (util <= kink) {
            return baseRate + (util * slopeLow) / 1e18;
        } else {
            uint256 excessUtil = util - kink;
            return baseRate + (kink * slopeLow + excessUtil * slopeHigh) / 1e18;
        }
    }

    function utilization(address token) public view returns (uint256) {
        uint256 _supply = totalSupplied[token];
        if (_supply == 0) return 0;
        return (totalBorrowed[token] * 1e18) / _supply;
    }
}
