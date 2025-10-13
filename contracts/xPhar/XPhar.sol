// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";  
import {IERC20Extended} from "../interfaces/IERC20Extended.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {IVoter} from "../interfaces/IVoter.sol";
import {IXPhar} from "../interfaces/IXPhar.sol";
import {Errors} from "contracts/libraries/Errors.sol";
import {IVoteModule} from "../interfaces/IVoteModule.sol";


/// @title xPHAR contract for Pharaoh
/// @dev Staked version of PHAR that grants voting power
contract XPhar is ERC20, IXPhar, Pausable {
    using EnumerableSet for EnumerableSet.AddressSet;

    /**
     * Addresses
     */

    /// @inheritdoc IXPhar
    address public operator;

    /// @inheritdoc IXPhar
    address public immutable MINTER;
    /// @inheritdoc IXPhar
    address public immutable ACCESS_HUB;

    /// @inheritdoc IXPhar
    address public immutable VOTE_MODULE;

    /// @dev IERC20 declaration of PHAR
    IERC20Extended public immutable PHAR;
    /// @dev declare IVoter
    IVoter public immutable VOTER;

    /// @inheritdoc IXPhar
    uint256 public constant BASIS = 1_000_000;
    /// @inheritdoc IXPhar
    uint256 public constant SLASHING_PENALTY = 500_000;

    /// @dev stores the addresses that are exempt from transfer limitations when transferring out
    EnumerableSet.AddressSet exempt;
    /// @dev stores the addresses that are exempt from transfer limitations when transferring to them
    EnumerableSet.AddressSet exemptTo;

    /// @inheritdoc IXPhar
    uint256 public lastDistributedPeriod;
    /// @inheritdoc IXPhar
    uint256 public totalBurned;


    modifier onlyGovernance() {
        require(msg.sender == ACCESS_HUB, Errors.NOT_AUTHORIZED(msg.sender));
        _;
    }

    constructor(
        address _phar,
        address _voter,
        address _operator,
        address _accessHub,
        address _voteModule,
        address _minter
    ) ERC20("xPHAR", "xPHAR") {
        PHAR = IERC20Extended(_phar);
        VOTER = IVoter(_voter);
        MINTER = _minter;
        operator = _operator;
        ACCESS_HUB = _accessHub;
        VOTE_MODULE = _voteModule;

        /// @dev exempt voter, operator, and the vote module
        exempt.add(_voter);
        exempt.add(operator);
        exempt.add(VOTE_MODULE);

        exemptTo.add(VOTE_MODULE);

        /// @dev grab current period from voter
        lastDistributedPeriod = IVoter(_voter).getPeriod();
    }

    /// @inheritdoc IXPhar
    function pause() external onlyGovernance {
        _pause();
    }
    /// @inheritdoc IXPhar

    function unpause() external onlyGovernance {
        _unpause();
    }

    /**
     *
     */
    // ERC20 Overrides and Helpers
    /**
     *
     */
    function _update(address from, address to, uint256 value) internal override {
        /* cases we account for:
         *
         * minting and burning
         * if the "to" is part of the special exemptions
         * withdraw and deposit calls
         * if "from" is a gauge or feeDist
         *
         */

        uint8 _u;
        if (_isExempted(from, to)) {
            _u = 1;
        } else if (VOTER.isGauge(from) || VOTER.isFeeDistributor(from)) {
            /// @dev add to the exempt set
            exempt.add(from);
            _u = 1;
        }
        /// @dev if all previous checks are passed
        require(_u == 1, Errors.NOT_WHITELISTED(from));
        /// @dev call parent function
        super._update(from, to, value);
    }

    /// @dev internal check for the transfer whitelist
    function _isExempted(address _from, address _to) internal view returns (bool) {
        return (exempt.contains(_from) || _from == address(0) || _to == address(0) || exemptTo.contains(_to));
    }

    /**
     *
     */
    // General use functions
    /**
     *
     */

    /// @inheritdoc IXPhar
    function convertEmissionsToken(uint256 _amount) external whenNotPaused {
        /// @dev ensure the _amount is > 0
        require(_amount != 0, Errors.ZERO());
        /// @dev transfer from the caller to this address
        PHAR.transferFrom(msg.sender, address(this), _amount);
        /// @dev calculate penalty with rounding up to ensure minimum 50% burn
        /// @dev (amount * penalty + BASIS - 1) / BASIS rounds up
        uint256 penalty = ((_amount * SLASHING_PENALTY) + BASIS - 1) / BASIS;
        /// @dev burn the penalty
        PHAR.burn(penalty);
        /// @dev add to the total burned
        totalBurned += penalty;
        /// @dev mint the xPHAR to the caller 1:1 with the input amount
        _mint(msg.sender, _amount);
        
        /// @dev emit an event for conversion
        emit Converted(msg.sender, _amount);
    }

    /// @inheritdoc IXPhar
    function rebase() external whenNotPaused {
        /// @dev gate to minter and call it on epoch flips
        require(msg.sender == MINTER, Errors.NOT_AUTHORIZED(msg.sender));
        /// @dev fetch the current period
        uint256 period = VOTER.getPeriod();
        /// @dev if it's a new period (epoch)
        if (
            period > lastDistributedPeriod
        ) {
            /// @dev ORIGINAL: PvP rebase notified to the voteModule staking contract to stream to xPHAR after epoch flips
            /// @dev NEW: No rebase, but kept for interfacing
            /// @dev fetch the current period from voter
            lastDistributedPeriod = period;
            /// @dev notify the PHAR rebase
            IVoteModule(VOTE_MODULE).notifyRewardAmount(0);
            emit Rebase(msg.sender, 0);
        }
    }

    /// @inheritdoc IXPhar
    function exit(uint256 _amount) external whenNotPaused returns (uint256 _exitedAmount) {
        /// @dev cannot exit a 0 amount
        require(_amount != 0, Errors.ZERO());
        /// @dev calculate penalty with rounding up to ensure minimum 50% penalty
        /// @dev (amount * penalty + BASIS - 1) / BASIS rounds up
        uint256 penalty = ((_amount * SLASHING_PENALTY) + BASIS - 1) / BASIS;
        uint256 exitAmount = _amount - penalty;
        
        /// @dev cap exitAmount to available balance (offsets round-up accumulation)
        exitAmount = Math.min(exitAmount, PHAR.balanceOf(address(this)));

        /// @dev burn the xPHAR from the caller's address
        _burn(msg.sender, _amount);

        /// @dev transfer the exitAmount to the caller
        PHAR.transfer(msg.sender, exitAmount);
        /// @dev emit actual exited amount
        emit InstantExit(msg.sender, exitAmount);
        return exitAmount;
    }

    /**
     *
     */
    // Permissioned functions, timelock/operator gated
    /**
     *
     */

    /// @inheritdoc IXPhar
    function rescueTrappedTokens(address[] calldata _tokens, uint256[] calldata _amounts) external onlyGovernance {
        for (uint256 i = 0; i < _tokens.length; ++i) {
            /// @dev cant fetch the underlying
            require(_tokens[i] != address(PHAR), Errors.CANT_RESCUE());
            IERC20(_tokens[i]).transfer(operator, _amounts[i]);
        }
    }

    /// @inheritdoc IXPhar
    function migrateOperator(address _operator) external onlyGovernance {
        /// @dev ensure operator is different
        require(operator != _operator, Errors.NO_CHANGE());
        emit NewOperator(operator, _operator);
        operator = _operator;
    }

    /// @inheritdoc IXPhar
    function setExemption(address[] calldata _exemptee, bool[] calldata _exempt) external onlyGovernance {
        /// @dev ensure arrays of same length
        require(_exemptee.length == _exempt.length, Errors.ARRAY_LENGTHS());
        /// @dev loop through all and attempt add/remove based on status
        for (uint256 i = 0; i < _exempt.length; ++i) {
            bool success = _exempt[i] ? exempt.add(_exemptee[i]) : exempt.remove(_exemptee[i]);
            /// @dev emit : (who, status, success)
            emit Exemption(_exemptee[i], _exempt[i], success);
        }
    }

    /// @inheritdoc IXPhar
    function setExemptionTo(address[] calldata _exemptee, bool[] calldata _exempt) external onlyGovernance {
        /// @dev ensure arrays of same length
        require(_exemptee.length == _exempt.length, Errors.ARRAY_LENGTHS());
        /// @dev loop through all and attempt add/remove based on status
        for (uint256 i = 0; i < _exempt.length; ++i) {
            bool success = _exempt[i] ? exemptTo.add(_exemptee[i]) : exemptTo.remove(_exemptee[i]);
            /// @dev emit : (who, status, success)
            emit Exemption(_exemptee[i], _exempt[i], success);
        }
    }


    /**
     *
     */
    // Getter functions
    /**
     *
     */

    /// @inheritdoc IXPhar
    function getBalanceResiding() public view returns (uint256 _amount) {
        /// @dev simply returns the balance of the underlying
        return PHAR.balanceOf(address(this));
    }

    /// @inheritdoc IXPhar
    function isExempt(address _who) external view returns (bool _exempt) {
        return exempt.contains(_who);
    }

    /// @inheritdoc IXPhar
    function isExemptTo(address _who) external view returns (bool _exempt) {
        return exemptTo.contains(_who);
    }

    /// @inheritdoc IXPhar
    function phar() external view returns (address) {
        return address(PHAR);
    }
}
