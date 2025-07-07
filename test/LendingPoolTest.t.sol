// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/LendingPool.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1_000_000 ether);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract LendingPoolTest is Test {
    uint256 constant SECONDS_PER_YEAR = 31536000;
    LendingPool pool;
    MockERC20 tokenA;
    MockERC20 tokenB;
    address user1 = address(1);
    address user2 = address(2);

    function setUp() public {
        tokenA = new MockERC20("MockA", "A");
        tokenB = new MockERC20("MockB", "B");
        pool = new LendingPool();

        tokenA.mint(user1, 1_000 ether);
        tokenA.mint(user2, 1_000 ether);
        tokenB.mint(user1, 1_000 ether);
        tokenB.mint(user2, 1_000 ether);

        vm.prank(user1);
        tokenA.approve(address(pool), type(uint256).max);
        vm.prank(user1);
        tokenB.approve(address(pool), type(uint256).max);
        vm.prank(user2);
        tokenA.approve(address(pool), type(uint256).max);
        vm.prank(user2);
        tokenB.approve(address(pool), type(uint256).max);
    }

    function testSupplyWithdraw() public {
        vm.prank(user1);
        pool.supply(tokenA, 100 ether);
        assertEq(pool.collateral(user1, address(tokenA)), 100 ether);
        assertEq(pool.totalSupplied(address(tokenA)), 100 ether);

        vm.prank(user1);
        pool.withdraw(tokenA, 40 ether);
        assertEq(pool.collateral(user1, address(tokenA)), 60 ether);
        assertEq(pool.totalSupplied(address(tokenA)), 60 ether);
    }

    function testBorrowAndRepay() public {
        vm.prank(user1);
        pool.supply(tokenA, 200 ether);

        vm.prank(user1);
        pool.borrow(tokenA, 80 ether);
        assertEq(pool.borrowed(user1, address(tokenA)), 80 ether);

        vm.prank(user1);
        pool.repay(tokenA, 80 ether);
        assertEq(pool.borrowed(user1, address(tokenA)), 0 ether);
    }

    function testCannotOverBorrow() public {
        vm.prank(user1);
        pool.supply(tokenA, 100 ether);

        vm.expectRevert();
        vm.prank(user1);
        pool.borrow(tokenA, 60 ether); // exceeds 50% LTV
    }

    function testInterestAccrual() public {
        vm.prank(user1);
        pool.supply(tokenA, 500 ether);

        vm.prank(user1);
        pool.borrow(tokenA, 200 ether);

        skip(31536000); // 1 year

        uint256 interest = pool.accruedInterest(user1, address(tokenA));
        assertGt(interest, 0);

        vm.prank(user1);
        pool.repay(tokenA, 200 ether + interest);

        assertApproxEqAbs(pool.borrowed(user1, address(tokenA)), 0, 1);
    }

    function testLiquidation() public {
    vm.startPrank(user1);
    pool.supply(tokenA, 100 ether);
    pool.borrow(tokenA, 50 ether);
    vm.stopPrank();

    skip(SECONDS_PER_YEAR);

    vm.startPrank(user1);
    tokenA.mint(user1, 1 ether);
    tokenA.approve(address(pool), type(uint256).max);
    pool.repay(tokenA, 1 ether); // triggers interest accrual
    vm.stopPrank();

    uint256 debt = pool.borrowed(user1, address(tokenA));
    assertGt(debt, 50 ether, "Debt should have grown via interest");

    // Mint to pool to fund liquidation
    tokenA.mint(address(pool), 20 ether);

    vm.startPrank(user2);
    tokenA.mint(user2, debt);
    tokenA.approve(address(pool), type(uint256).max);
    pool.liquidate(tokenA, user1, debt);
    vm.stopPrank();

    assertEq(pool.borrowed(user1, address(tokenA)), 0);
}

    function testDifferentTokensIsolated() public {
        vm.prank(user1);
        pool.supply(tokenA, 100 ether);

        vm.prank(user1);
        pool.supply(tokenB, 50 ether);

        vm.prank(user1);
        pool.borrow(tokenA, 40 ether);

        vm.prank(user1);
        pool.borrow(tokenB, 20 ether);

        assertEq(pool.borrowed(user1, address(tokenA)), 40 ether);
        assertEq(pool.borrowed(user1, address(tokenB)), 20 ether);
    }

    function testUtilizationAndRate() public {
        vm.prank(user1);
        pool.supply(tokenA, 1000 ether);

        vm.prank(user1);
        pool.borrow(tokenA, 500 ether);

        uint256 util = pool.utilization(address(tokenA));
        assertEq(util, 0.5e18); // 50%

        uint256 rate = pool.getBorrowRate(address(tokenA));
        assertGt(rate, 0);
    }
}
