// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {IRebaseToken} from "src/interfaces/IRebaseToken.sol";
import {RebaseToken} from "src/RebaseToken.sol";
import {Vault} from "src/Vault.sol";
import {Test} from "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract RebaseTokenTest is Test {
    RebaseToken private rebaseToken;
    Vault private vault;

    address private USER = makeAddr("user");
    address private OWNER = makeAddr("owner");

    function setUp() public {
        vm.startPrank(OWNER);
        rebaseToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(rebaseToken)));
        rebaseToken.setMintAndBurnRole(address(vault));
        vm.stopPrank();
    }

    function depositReward(uint256 amount) public {
        (bool success,) = payable(address(vault)).call{value: amount}("");
    }

    function testLinearDeposit(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        vm.startPrank(USER);
        vm.deal(USER, amount);

        vault.deposit{value: amount}();
        uint256 startBalance = rebaseToken.balanceOf(USER);
        assertEq(startBalance, amount, "Deposit failed");

        vm.warp(block.timestamp + 1 hours);
        uint256 middleBalance = rebaseToken.balanceOf(USER);
        assertGt(middleBalance, startBalance, "Interest not accrued");

        vm.warp(block.timestamp + 1 hours);
        uint256 endBalance = rebaseToken.balanceOf(USER);
        assertGt(endBalance, middleBalance, "Interest not accrued");

        assertApproxEqAbs(endBalance - middleBalance, middleBalance - startBalance, 1, "Interest not accrued");
        vm.stopPrank();
    }

    function testRedeemTokenInstantly(uint256 amount) public {
        vm.startPrank(USER);
        amount = bound(amount, 1e5, type(uint96).max);
        vm.deal(USER, amount);
        vault.deposit{value: amount}();
        assertEq(rebaseToken.balanceOf(USER), amount);

        vault.redeem(type(uint256).max);
        assertEq(rebaseToken.balanceOf(USER), 0);

        assertEq(address(USER).balance, amount);
    }

    function testRdeemAfterSomeTimePassed(uint256 depositAmount, uint256 time) public {
        time = bound(time, 1000, type(uint96).max);
        depositAmount = bound(depositAmount, 1e5, type(uint96).max);

        vm.deal(USER, depositAmount);
        vm.prank(USER);
        vault.deposit{value: depositAmount}();
        assertEq(rebaseToken.balanceOf(USER), depositAmount);

        vm.warp(block.timestamp + time);

        uint256 balanceAfterSomeTime = rebaseToken.balanceOf(USER);

        vm.deal(OWNER, balanceAfterSomeTime - depositAmount);
        vm.prank(OWNER);
        depositReward(balanceAfterSomeTime - depositAmount);

        vm.prank(USER);
        vault.redeem(type(uint256).max);
        assertEq(rebaseToken.balanceOf(USER), 0);
        assertGt(address(USER).balance, depositAmount, "Interest not accrued");
    }

    function testTransfer(uint256 amount, uint256 amountToTransfer) public {
        amount = bound(amount, 1e5 + 1e5, type(uint96).max);
        amountToTransfer = bound(amountToTransfer, 1e5, amount - 1e5);

        address USER2 = makeAddr("user2");

        vm.deal(USER, amount);
        vm.prank(USER);
        vault.deposit{value: amount}();
        assertEq(rebaseToken.balanceOf(USER), amount);
        assertEq(rebaseToken.balanceOf(USER2), 0);

        vm.prank(OWNER);
        rebaseToken.setInterestRate(4e10);

        vm.prank(USER);
        rebaseToken.transfer(USER2, amountToTransfer);
        assertEq(rebaseToken.balanceOf(USER), amount - amountToTransfer);
        assertEq(rebaseToken.balanceOf(USER2), amountToTransfer);

        assertEq(rebaseToken.getUserInterestRate(USER2), 5e10);
    }

    function testCannotSetInterestRateIfNotUser(uint256 newInterestRate) public {
        vm.prank(USER);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, USER));
        rebaseToken.setInterestRate(newInterestRate);
    }

    function testCannotMintAndBurnIfNotVault() public {
        vm.prank(USER);
        vm.expectPartialRevert(IAccessControl.AccessControlUnauthorizedAccount.selector);
        rebaseToken.mint(USER, 100, rebaseToken.getInterestRate());
        vm.expectPartialRevert(IAccessControl.AccessControlUnauthorizedAccount.selector);
        rebaseToken.burn(USER, 100);
    }
}
