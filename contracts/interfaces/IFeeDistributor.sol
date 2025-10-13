// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IVoter} from "../interfaces/IVoter.sol";
import {IVoteModule} from "../interfaces/IVoteModule.sol";

interface IFeeDistributor {
    event Deposit(address owner, uint256 amount);

    event Withdraw(address owner, uint256 amount);

    event NotifyReward(address indexed from, address indexed reward, uint256 amount, uint256 period);

    event VotesIncentivized(address indexed from, address indexed reward, uint256 amount, uint256 period);

    event ClaimRewards(uint256 period, address owner, address receiver, address reward, uint256 amount);

    event RewardsRedirected(address indexed destination, address indexed _reward, uint256 _amount);

    event RewardsRemoved(address _reward);

    /// @notice the address of the voter contract
    function voter() external view returns (IVoter);
    /// @notice the address of the voting module
    function voteModule() external view returns (IVoteModule);
    /// @notice the address of the feeRecipient contract
    function feeRecipient() external view returns (address);

    /// @notice the first period (epoch) that this contract was deployed
    function firstPeriod() external view returns (uint256);

    /// @notice balance of the voting power for a user
    /// @param owner the owner
    /// @return amount the amount of voting share
    function balanceOf(address owner) external view returns (uint256 amount);

    /// @notice total cumulative amount of voting power per epoch
    /// @param period the period to check
    /// @return weight the amount of total voting power
    function votes(uint256 period) external view returns (uint256 weight);

    /// @notice "internal" function gated to voter to add votes
    /// @dev internal notation inherited from original solidly, kept for continuity
    function _deposit(uint256 amount, address owner) external;
    /// @notice "internal" function gated to voter to remove votes
    /// @dev internal notation inherited from original solidly, kept for continuity
    function _withdraw(uint256 amount, address owner) external;

    /// @notice function to claim rewards on behalf of another
    /// @param owner owner's address
    /// @param tokens an array of the tokens
    function getRewardForOwner(address owner, address[] memory tokens) external;

    /// @notice function to claim rewards on behalf of another
    /// @param owner owner's address
    /// @param tokens an array of the tokens
    /// @param destination destination of the rewards
    function getRewardForOwnerTo(address owner, address[] memory tokens, address destination) external;

    /// @notice function for sending fees directly to be claimable (in system where fees are distro'd through the week)
    /// @dev for lumpsum - this would operate similarly to incentivize
    /// @param token the address of the token to send for notifying
    /// @param amount the amount of token to send
    function notifyRewardAmount(address token, uint256 amount) external;

    /// @notice gives an array of reward tokens for the feedist
    /// @return _rewards array of rewards
    function getRewardTokens() external view returns (address[] memory _rewards);

    /// @notice shows the earned incentives in the feedist
    /// @param token the token address to check
    /// @param owner owner's address
    /// @return reward the amount earned/claimable
    function earned(address token, address owner) external view returns (uint256 reward);

    /// @notice function to submit incentives to voters for the upcoming flip
    /// @param token the address of the token to send for incentivization
    /// @param amount the amount of token to send
    function incentivize(address token, uint256 amount) external;

    /// @notice get the rewards for a specific period
    /// @param owner owner's address
    function getPeriodReward(uint256 period, address owner, address token) external;
    /// @notice get the fees and incentives
    function getReward(address owner, address[] memory tokens) external;

    /// @notice remove a reward from the set
    function removeReward(address _token) external;

    /// @notice claws back rewards
    function clawbackRewards(address token, address destination) external;

    /// @notice reward supply for a specific period
    function rewardSupply(uint256 period, address token) external returns (uint256);

    /// @notice reward supply for a specific period
    function userVotes(uint256 period, address owner) external returns (uint256 weight);
}
