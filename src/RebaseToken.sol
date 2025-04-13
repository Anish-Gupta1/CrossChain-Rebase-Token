// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title RebaseToken
 * @author Anish
 * @notice This is a cross chain rebase token that incentivises user to deposit into a vault and in return and gain interest
 * @notice The interest rate in the smart contract can only decrease
 * @notice Each user will have their own interest rate that is the global interest rate based on the time of depositing
 *
 */
contract RebaseToken is ERC20, Ownable, AccessControl {
    error RebaseToken__InterestRateCanOnlyDecrease(uint256 oldInterestRate, uint256 newInterestRate);

    uint256 private constant PRECISION_FACTOR = 1e18;
    bytes32 private constant MINT_AND_BURN_ROLE = keccak256("MINT_AND_BURN_ROLE");
    uint256 private s_interestRate = 5e10;
    mapping(address => uint256) private s_userInterestRate;
    mapping(address => uint256) private s_userLastUpdatedTimestamp;

    event InterestRateSet(uint256 interestRate);

    constructor() ERC20("RebaseToken", "RBT") Ownable(msg.sender) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function grantMintAndBurnRole(address _account) external onlyOwner {
        // grant the mint and burn role to the account
        _grantRole(MINT_AND_BURN_ROLE, _account);
    }

    function setInterestRate(uint256 _interestRate) external onlyOwner {
        // set the interest rate
        if (_interestRate < s_interestRate) {
            revert RebaseToken__InterestRateCanOnlyDecrease(s_interestRate, _interestRate);
        }
        s_interestRate = _interestRate;
        emit InterestRateSet(_interestRate);
    }

    function principleBalanceOf(address _user) external view returns (uint256) {
        return super.balanceOf(_user);
    }

    function mint(address _to, uint256 _amount) external onlyRole(MINT_AND_BURN_ROLE) {
        // mint the token
        _mintAccruedInterest(_to);
        s_userInterestRate[_to] = s_interestRate;
        _mint(_to, _amount);
    }

    function burn(address _from, uint256 _amount) external onlyRole(MINT_AND_BURN_ROLE) {
        if (_amount == type(uint256).max) {
            _amount = balanceOf(_from);
        }
        _mintAccruedInterest(_from);
        _burn(_from, _amount);
    }

    function balanceOf(address _user) public view override returns (uint256) {
        return super.balanceOf(_user) + _calculateUserAccumulaatedInterestSinceLastUpdate(_user) / PRECISION_FACTOR;
    }

    function transfer(address _recipient, uint256 _amount) public override returns (bool) {
        _mintAccruedInterest(msg.sender);
        _mintAccruedInterest(_recipient);
        if (_amount == type(uint256).max) {
            _amount = balanceOf(msg.sender);
        }
        if (balanceOf(_recipient) == 0) {
            s_userInterestRate[_recipient] = s_userInterestRate[msg.sender];
        }
        return super.transfer(_recipient, _amount);
    }

    function transferFrom(address _sender, address _recipient, uint256 _amount) public override returns (bool) {
        _mintAccruedInterest(_sender);
        _mintAccruedInterest(_recipient);
        if (_amount == type(uint256).max) {
            _amount = balanceOf(_sender);
        }
        if (balanceOf(_recipient) == 0) {
            s_userInterestRate[_recipient] = s_userInterestRate[_sender];
        }
        return super.transfer(_recipient, _amount);
    }

    function _calculateUserAccumulaatedInterestSinceLastUpdate(address _user)
        internal
        view
        returns (uint256 linearInterest)
    {
        uint256 timeElapsed = block.timestamp - s_userLastUpdatedTimestamp[_user];
        linearInterest = PRECISION_FACTOR + (s_userInterestRate[_user] * timeElapsed);
    }

    function _mintAccruedInterest(address _user) internal {
        // (1) find User's rebase token that has been minted
        uint256 previousPrincipleBalance = super.balanceOf(_user);
        // (2) calculate the current balance of the user including the interest
        uint256 currentBalance = balanceOf(_user);
        // calculate the number of token that needs to be minted for the user -> (2) - (1)
        uint256 balanceIncrease = currentBalance - previousPrincipleBalance;
        // set user last updated time
        s_userLastUpdatedTimestamp[_user] = block.timestamp;
        // (3) mint the token to the user
        _mint(_user, balanceIncrease);
    }

    function getInterestRate() external view returns (uint256) {
        return s_interestRate;
    }

    function getUserInterestRate(address _user) external view returns (uint256) {
        return s_userInterestRate[_user];
    }
}
