// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title RebaseToken
 * @author Anish
 * @notice This is a cross chain rebase token that incentivises user to deposit into a vault and in return and gain interest
 * @notice The interest rate in the smart contract can only decrease
 * @notice Each user will have their own interest rate that is the global interest rate based on the time of depositing
 *
 */
contract RebaseToken is ERC20 {
    error RebaseToken__InterestRateCanOnlyDecrease(uint256 oldInterestRate, uint256 newInterestRate);

    uint256 private constant PRECISION_FACTOR = 1e18;
    uint256 private s_interestRate = 5e10;
    mapping(address => uint256) private s_userInterestRate;
    mapping(address => uint256) private s_userLastUpdatedTimestamp;

    event InterestRateSet(uint256 interestRate);

    constructor() ERC20("RebaseToken", "RBT") {}

    function setInterestRate(uint256 _interestRate) external {
        // set the interest rate
        if (_interestRate < s_interestRate) {
            revert RebaseToken__InterestRateCanOnlyDecrease(s_interestRate, _interestRate);
        }
        s_interestRate = _interestRate;
        emit InterestRateSet(_interestRate);
    }

    function mint(address _to, uint256 _amount) external {
        // mint the token
        _mintAccruedInterest(_to);
        s_userInterestRate[_to] = s_interestRate;
        _mint(_to, _amount);
    }

    function getUserInterestRate(address _user) external view returns (uint256) {
        // get the user interest rate
        return s_userInterestRate[_user];
    }

    function balanceOf(address _user) public view override returns (uint256) {
        return super.balanceOf(_user) + _calculateUserAccumulaatedInterestSinceLastUpdate(_user) / PRECISION_FACTOR;
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
        // (2) calculate the current balance of the user including the interest
        // calculate the number of token that needs to be minted for the user -> (2) - (1)
        // (3) mint the token to the user
        s_userLastUpdatedTimestamp[_user] = block.timestamp;
    }
}
