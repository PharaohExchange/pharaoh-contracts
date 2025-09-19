// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IFeeDistributor} from "./interfaces/IFeeDistributor.sol";
import {IFeeRecipient} from "./interfaces/IFeeRecipient.sol";
import {IFeeRecipientFactory} from "./interfaces/IFeeRecipientFactory.sol";
import {Errors} from "contracts/libraries/Errors.sol";

/// @notice Pair Fees contract is used as a 1:1 pair relationship to split out fees, this ensures that the curve does not need to be modified for LP shares
contract FeeRecipient is IFeeRecipient {
    /// @notice The pair it is bonded to
    address public immutable pair;
    /// @notice voter contract which fees are gated to be claimed by
    address public immutable voter;
    /// @notice feedist contract where fees will be sent to
    address public feeDistributor;
    /// @notice factory contract for feeRecipient (legacy fees)
    address public immutable feeRecipientFactory;

    uint256 internal constant FEE_DENOM = 1_000_000;

    constructor(address _pair, address _voter, address _feeRecipientFactory) {
        pair = _pair;
        voter = _voter;
        feeRecipientFactory = _feeRecipientFactory;
    }

    /// @notice initialize the FeeRecipient contract and approve the LP tokens to the feeDist, gated to voter
    function initialize(address _feeDistributor) external {
        require(msg.sender == voter, Errors.NOT_AUTHORIZED(msg.sender));
        feeDistributor = _feeDistributor;
        IERC20(pair).approve(_feeDistributor, type(uint256).max);
    }

    /// @notice notifies the fees
    function notifyFees() external {
        /// @dev fetch balance of LP in the contract
        uint256 amount = IERC20(pair).balanceOf(address(this));
        /// @dev terminate early if there's no rewards
        if (amount == 0) return;
        /// @dev calculate treasury share
        uint256 feeToTreasury = IFeeRecipientFactory(feeRecipientFactory).feeToTreasury();
        /// @dev if any to treasury
        if (feeToTreasury > 0) {
            /// @dev fetch treasury from factory
            address treasury = IFeeRecipientFactory(feeRecipientFactory).treasury();
            /// @dev mulDiv
            uint256 amountToTreasury = (amount * feeToTreasury) / FEE_DENOM;
            /// @dev decrement amount
            amount -= amountToTreasury;
            /// @dev naked transfer to treasury, no staking
            IERC20(pair).transfer(treasury, amountToTreasury);
        }

        /// @dev if there's any fees
        if (amount > 0) {
            IFeeDistributor(feeDistributor).notifyRewardAmount(pair, amount);
        }
    }
}
