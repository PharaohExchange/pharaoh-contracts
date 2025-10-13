// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IXPhar} from "contracts/interfaces/IXPhar.sol";

interface IP33 is IERC20  {
    /// @dev parameters passed to the aggregator swap
    struct AggregatorParams {
        address aggregator; // address of the whitelisted aggregator
        address tokenIn; // token to swap from
        uint256 amountIn; // amount of tokenIn to swap
        uint256 minAmountOut; // minimum amount of tokenOut to receive
        bytes callData; // encoded swap calldata
    }

    event Entered(address indexed user, uint256 amount, uint256 ratioAtDeposit);
    event Exited(address indexed user, uint256 _outAmount, uint256 ratioAtWithdrawal);

    event NewOperator(address _oldOperator, address _newOperator);
    event Compounded(uint256 oldRatio, uint256 newRatio, uint256 amount);
    event SwappedBribe(address indexed operator, address indexed tokenIn, uint256 amountIn, uint256 amountOut);
    event Rebased(uint256 oldRatio, uint256 newRatio, uint256 amount);
    /// @notice Event emitted when an aggregator's whitelist status changes
    event AggregatorWhitelistUpdated(address aggregator, bool status);

    event Unlocked(uint256 _ts);

    event UpdatedIndex(uint256 _index);

    event ClaimedIncentives(address[] feeDistributors, address[][] tokens);

    function whitelistedAggregators(address aggregator) external returns (bool);

    /// @notice submits the optimized votes for the epoch
    function submitVotes(address[] calldata _pools, uint256[] calldata _weights) external;

    /// @notice swap function using aggregators to process rewards into RAM
    function swapIncentiveViaAggregator(AggregatorParams calldata _params) external;

    /// @notice compounds any existing RAM within the contract
    function compound() external;

    /// @notice direct claim
    function claimIncentives(address[] calldata _feeDistributors, address[][] calldata _tokens) external;

    /// @notice rescue stuck tokens
    function rescue(address _token, uint256 _amount) external;

    /// @notice allows the operator to unlock the contract for the current period
    function unlock() external;

    /// @notice add or remove an aggregator from the whitelist (timelocked)
    /// @param _aggregator address of the aggregator to update
    /// @param _status new whitelist status
    function whitelistAggregator(address _aggregator, bool _status) external;

    /// @notice transfers the operator via accesshub
    function transferOperator(address _newOperator) external;

    /// @notice simple getPeriod call
    function getPeriod() external view returns (uint256 period);

    /// @notice if the contract is unlocked for deposits
    function isUnlocked() external view returns (bool);

    /// @notice determines whether the cooldown is active
    function isCooldownActive() external view returns (bool);

    /// @notice address of the current operator
    function operator() external view returns (address);

    /// @notice accessHub address
    function accessHub() external view returns (address);

    /// @notice returns the ratio of xRam per X33 token
    function ratio() external view returns (uint256 _ratio);

    /// @notice whether the periods are unlocked
    function periodUnlockStatus(uint256 _period) external view returns (bool unlocked);

    /// @notice the phar token
    function phar() external view returns (IERC20);

    /// @notice the xPHAR token
    function xPhar() external view returns (IXPhar);

  
}
