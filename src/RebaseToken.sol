// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title Rebase Token
 * @author TeeJay
 * @notice Implements a cross-chain ERC20 token where balances increase automatically over time.
 * @dev This contract uses a rebasing mechanism based on a per-second interest rate.
 * The global interest rate can only increase or stay the same. Each user gets assigned
 * the prevailing global interest rate upon their first interaction involving balance updates.
 * Balances are calculated dynamically in the `balanceOf` function.
 */
contract RebaseToken is ERC20, Ownable, AccessControl {
    error RebaseToken__InterestRateCanOnlyDecrease(uint256 newInterestRate, uint256 oldInterestRate);
    error RebaseToken__NoInterestAccrued();

    uint256 private s_interestRate = 5e10;
    uint256 private constant PRECISION_FACTOR = 1e18;
    bytes32 private constant MINT_AND_BURN_ROLE = keccak256("MINT_AND_BURN_ROLE");

    mapping(address => uint256) private s_userInterestRate;
    mapping(address => uint256) private s_userLastUpdatedTimestamp;

    event IncreasedRate(uint256 newInterestRate);

    constructor() ERC20("Rebase Token", "RBT") Ownable(msg.sender) {}

    /**
     * @notice Sets the global interest rate for the token contract.
     * @dev Reverts if the proposed rate is lower than the current rate.
     * Emits an {InterestRateSet} event on success.
     * @param _newInterestRate The desired new global interest rate per second (scaled by PRECISION_FACTOR).
     */
    function setInterestRate(uint256 _newInterestRate) external onlyOwner {
        if (_newInterestRate > s_interestRate) {
            revert RebaseToken__InterestRateCanOnlyDecrease(_newInterestRate, s_interestRate);
        }
        s_interestRate = _newInterestRate;
        emit IncreasedRate(_newInterestRate);
    }

    function setMintAndBurnRole(address _account) external onlyOwner {
        _grantRole(MINT_AND_BURN_ROLE, _account);
    }

    function revokeMintAndBurnRole(address _account) external onlyOwner {
        _revokeRole(MINT_AND_BURN_ROLE, _account);
    }

    function mint(address _to, uint256 _amount, uint256 _userInterestRate) external onlyRole(MINT_AND_BURN_ROLE) {
        _mintAccruedInterest(_to);
        _mint(_to, _amount);
        s_userInterestRate[_to] = _userInterestRate;
    }

    function burn(address _from, uint256 _amount) external onlyRole(MINT_AND_BURN_ROLE) {
        _mintAccruedInterest(_from);
        _burn(_from, _amount);
    }

    function transfer(address _to, uint256 _amount) public override returns (bool) {
        _mintAccruedInterest(msg.sender);
        _mintAccruedInterest(_to);

        if (_amount == type(uint256).max) {
            _amount = balanceOf(msg.sender);
        }

        if (balanceOf(_to) == 0) {
            s_userInterestRate[_to] = s_userInterestRate[msg.sender];
        }
        return super.transfer(_to, _amount);
    }

    function transferFrom(address _from, address _to, uint256 _amount) public override returns (bool) {
        _mintAccruedInterest(_from);
        _mintAccruedInterest(_to);

        if (_amount == type(uint256).max) {
            _amount = balanceOf(_from);
        }

        if (balanceOf(_to) == 0) {
            s_userInterestRate[_to] = s_userInterestRate[_from];
        }
        return super.transferFrom(_from, _to, _amount);
    }

    function balanceOf(address _user) public view override returns (uint256) {
        return super.balanceOf(_user) * _calculateUserAccumulatedInterestsSinceLastUpdated(_user) / PRECISION_FACTOR;
    }

    /**
     * @notice Calculates the interest multiplier for a user since their last update.
     * @dev The multiplier represents (1 + (user_rate * time_elapsed)).
     * The result is scaled by PRECISION_FACTOR.
     * @param _user The address of the user.
     * @return linearInterest The calculated interest multiplier (scaled).
     */
    function _calculateUserAccumulatedInterestsSinceLastUpdated(address _user)
        internal
        view
        returns (uint256 linearInterest)
    {
        uint256 timeElapsed = block.timestamp - s_userLastUpdatedTimestamp[_user];
        uint256 userRate = s_userInterestRate[_user];
        linearInterest = PRECISION_FACTOR + ((userRate * timeElapsed));
    }

    function _mintAccruedInterest(address _user) internal {
        uint256 userPreviousBalance = super.balanceOf(_user);
        uint256 userUpdatedBalance = balanceOf(_user);
        uint256 balanceIncrease = userUpdatedBalance - userPreviousBalance;

        s_userLastUpdatedTimestamp[_user] = block.timestamp;
        _mint(_user, balanceIncrease);
    }

    function getPrincipalBalance(address _user) external view returns (uint256) {
        return super.balanceOf(_user);
    }

    function getInterestRate() external view returns (uint256) {
        return s_interestRate;
    }

    function getUserInterestRate(address _user) external view returns (uint256) {
        return s_userInterestRate[_user];
    }
}
