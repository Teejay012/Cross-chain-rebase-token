// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {IRebaseToken} from "./interfaces/IRebaseToken.sol";

contract Vault {
    error Vault__TransferFailed();

    IRebaseToken private immutable i_rebaseTokenAddress;

    event Deposit(address indexed user, uint256 amount);
    event Redeem(address indexed user, uint256 amount);

    constructor(IRebaseToken _rebaseTokenAddress) {
        i_rebaseTokenAddress = _rebaseTokenAddress;
    }

    receive() external payable {}

    function deposit() external payable {
        uint256 interestRate = i_rebaseTokenAddress.getInterestRate();
        i_rebaseTokenAddress.mint(msg.sender, msg.value, interestRate);
        emit Deposit(msg.sender, msg.value);
    }

    function redeem(uint256 _amount) external payable {
        if (_amount == type(uint256).max) {
            _amount = i_rebaseTokenAddress.balanceOf(msg.sender);
        }
        i_rebaseTokenAddress.burn(msg.sender, _amount);
        (bool success,) = payable(msg.sender).call{value: _amount}("");
        if (!success) {
            revert Vault__TransferFailed();
        }
        emit Redeem(msg.sender, _amount);
    }

    function getRebaseTokenAddress() external view returns (address) {
        return address(i_rebaseTokenAddress);
    }
}
