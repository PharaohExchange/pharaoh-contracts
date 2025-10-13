// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {IVoter} from "../interfaces/IVoter.sol";
import {IXPhar} from "../interfaces/IXPhar.sol";
import {IVoteModule} from "../interfaces/IVoteModule.sol";
import {IP33} from "../interfaces/IP33.sol";
import {Errors} from "contracts/libraries/Errors.sol";
import {IAccessHub} from "../interfaces/IAccessHub.sol";

/// @title Canonical xPhar Wrapper for Pharaoh
/// @dev Autocompounding shares token voting optimally each epoch
contract P33 is ERC4626, IP33, ReentrancyGuard {
    using SafeERC20 for ERC20;

    /// @inheritdoc IP33
    address public operator;

    /// @inheritdoc IP33
    address public immutable accessHub;

    IERC20 public immutable phar;
    IXPhar public immutable xPhar;
    IVoteModule public immutable voteModule;
    IVoter public immutable voter;

    /// @inheritdoc IP33
    mapping(uint256 => bool) public periodUnlockStatus;

    /// @notice Mapping of whitelisted aggregators
    mapping(address => bool) public whitelistedAggregators;

    modifier whileNotLocked() {
        require(isUnlocked(), Errors.LOCKED());
        _;
    }

    modifier onlyOperator() {
        require(msg.sender == operator, Errors.NOT_AUTHORIZED(msg.sender));
        _;
    }

    modifier onlyAccessHub() {
        require(msg.sender == accessHub, Errors.NOT_ACCESSHUB());
        _;
    }

    constructor(address _operator, address _accessHub, address _xPhar, address _voter, address _voteModule)
        ERC20("Pharaoh Liquid Staking Token", "p33")
        ERC4626(IERC20(_xPhar))
    {
        operator = _operator;
        accessHub = _accessHub;
        xPhar = IXPhar(_xPhar);
        phar = IERC20(xPhar.PHAR());
        voteModule = IVoteModule(_voteModule);
        voter = IVoter(_voter);
        /// @dev pre-approve ram and xRam
        phar.approve(address(xPhar), type(uint256).max);
        xPhar.approve(address(voteModule), type(uint256).max);
    }

    /// @inheritdoc IP33
    function submitVotes(address[] calldata _pools, uint256[] calldata _weights) external onlyOperator {
        /// @dev cast vote on behalf of this address
        voter.vote(address(this), _pools, _weights);
    }

    /// @inheritdoc IP33
    function compound() external onlyOperator {
        /// @dev fetch the current ratio prior to compounding
        uint256 currentRatio = ratio();
        /// @dev cache the current ram balance
        uint256 currentRamBalance;
        /// @dev fetch from simple IERC20 call to the underlying RAM
        currentRamBalance = phar.balanceOf(address(this));
        /// @dev convert to xRam
        xPhar.convertEmissionsToken(currentRamBalance);
        /// @dev deposit into the voteModule
        voteModule.depositAll();
        /// @dev fetch new ratio
        uint256 newRatio = ratio();

        emit Compounded(currentRatio, newRatio, currentRamBalance);
    }

    /// @inheritdoc IP33
    function claimIncentives(address[] calldata _feeDistributors, address[][] calldata _tokens) external onlyOperator {
        /// @dev claim all voting rewards to x33 contract
        voter.claimIncentives(address(this), _feeDistributors, _tokens);
        emit ClaimedIncentives(_feeDistributors, _tokens);
    }

    /// @inheritdoc IP33
    function swapIncentiveViaAggregator(AggregatorParams calldata _params) external nonReentrant onlyOperator {
        /// @dev check to make sure the aggregator is supported
        require(whitelistedAggregators[_params.aggregator], Errors.AGGREGATOR_NOT_WHITELISTED(_params.aggregator));

        /// @dev required to validate later against malicious calldata
        /// @dev fetch underlying xRam in the votemodule before swap
        uint256 xRamBalanceBeforeSwap = totalAssets();
        /// @dev fetch the ramBalance of the contract
        uint256 ramBalanceBeforeSwap = phar.balanceOf(address(this));

        /// @dev swap via aggregator (swapping RAM is forbidden)
        require(_params.tokenIn != address(phar), Errors.FORBIDDEN_TOKEN(address(phar)));
        IERC20(_params.tokenIn).approve(_params.aggregator, _params.amountIn);
        (bool success, bytes memory returnData) = _params.aggregator.call(_params.callData);
        /// @dev revert with the returnData for debugging
        require(success, Errors.AGGREGATOR_REVERTED(returnData));

        /// @dev fetch the new balances after swap
        /// @dev ram balance after the swap
        uint256 ramBalanceAfterSwap = phar.balanceOf(address(this));
        /// @dev underlying xRam balance in the voteModule
        uint256 xRamBalanceAfterSwap = totalAssets();
        /// @dev the difference from ram before to after
        uint256 diffRam = ramBalanceAfterSwap - ramBalanceBeforeSwap;
        /// @dev ram tokenOut slippage check
        require(diffRam >= _params.minAmountOut, Errors.AMOUNT_OUT_TOO_LOW(diffRam));
        /// @dev prevent any holding xram on x33 to be manipulated (under any circumstance)
        require(xRamBalanceAfterSwap == xRamBalanceBeforeSwap, Errors.FORBIDDEN_TOKEN(address(xPhar)));

        emit SwappedBribe(operator, _params.tokenIn, _params.amountIn, diffRam);
    }

    /// @inheritdoc IP33
    function rescue(address _token, uint256 _amount) external nonReentrant onlyAccessHub {
        uint256 snapshotxRamBalance = totalAssets();

        /// @dev transfer to the caller
        IERC20(_token).transfer(msg.sender, _amount);

        /// @dev _token could be any malicious contract someone sent to the P33 module
        require(totalAssets() >= snapshotxRamBalance, Errors.FORBIDDEN_TOKEN(address(xPhar)));
    }

    /// @inheritdoc IP33
    function unlock() external onlyOperator {
        /// @dev block unlocking until the cooldown is concluded
        require(!isCooldownActive(), Errors.LOCKED());
        /// @dev unlock the current period
        periodUnlockStatus[getPeriod()] = true;

        emit Unlocked(block.timestamp);
    }
    /// @inheritdoc IP33

    function transferOperator(address _newOperator) external onlyAccessHub {
        address currentOperator = operator;

        /// @dev set the new operator
        operator = _newOperator;

        emit NewOperator(currentOperator, operator);
    }

    /// @inheritdoc IP33
    function whitelistAggregator(address _aggregator, bool _status) external onlyAccessHub {
        /// @dev add to the whitelisted aggregator mapping
        whitelistedAggregators[_aggregator] = _status;
        emit AggregatorWhitelistUpdated(_aggregator, _status);
    }
    /**
     * Read Functions
     */

    /// @inheritdoc ERC4626
    function totalAssets() public view override returns (uint256) {
        /// @dev simple call to the voteModule
        return voteModule.balanceOf(address(this));
    }

    /// @inheritdoc IP33
    function ratio() public view returns (uint256) {
        if (totalSupply() == 0) return 1e18;
        return (totalAssets() * 1e18) / totalSupply();
    }

    /// @inheritdoc IP33
    function getPeriod() public view returns (uint256 period) {
        period = block.timestamp / 1 weeks;
    }

    /// @inheritdoc IP33
    function isUnlocked() public view returns (bool) {
        /// @dev calculate the time left in the current period
        /// @dev getPeriod() + 1 can be viewed as the starting point of the NEXT period
        uint256 timeLeftInPeriod = ((getPeriod() + 1) * 1 weeks) - block.timestamp;
        /// @dev if there's <= 1 hour until flip, lock it
        /// @dev does not matter if the period is unlocked, block
        if (timeLeftInPeriod <= 1 hours) {
            return false;
        }
        /// @dev if it's unlocked and not within an hour until flip, allow interactions
        return periodUnlockStatus[getPeriod()];
    }

    /// @inheritdoc IP33
    function isCooldownActive() public view returns (bool) {
        /// @dev fetch the next unlock from the voteModule
        uint256 unlockTime = voteModule.unlockTime();
        return (block.timestamp >= unlockTime ? false : true);
    }

    /**
     * ERC4626 internal overrides
     */
    function _deposit(address caller, address receiver, uint256 assets, uint256 shares)
        internal
        virtual
        override
        whileNotLocked
    {
        SafeERC20.safeTransferFrom(xPhar, caller, address(this), assets);

        /// @dev deposit to the voteModule before minting shares to the user
        voteModule.deposit(assets);
        _mint(receiver, shares);

        emit Deposit(caller, receiver, assets, shares);
    }

    function _withdraw(address caller, address receiver, address owner, uint256 assets, uint256 shares)
        internal
        virtual
        override
    {
        if (caller != owner) {
            _spendAllowance(owner, caller, shares);
        }

        _burn(owner, shares);

        /// @dev withdraw from the voteModule before sending the user's xRam
        voteModule.withdraw(assets);

        SafeERC20.safeTransfer(xPhar, receiver, assets);

        emit Withdraw(caller, receiver, owner, assets, shares);
    }

}
