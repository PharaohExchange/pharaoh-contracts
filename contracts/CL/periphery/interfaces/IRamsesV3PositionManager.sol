// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.7.5;
pragma abicoder v2;

import {INonfungiblePositionManager} from './INonfungiblePositionManager.sol';

/// @title Ramses V3 Non-fungible token for positions
/// @notice Extends the standard NFT position manager with additional functionality
/// @dev This interface extends INonfungiblePositionManager with Ramses-specific features
interface IRamsesV3PositionManager is INonfungiblePositionManager {
    /// @notice Returns the last modification timestamp for a position
    /// @dev Used for extra checks in gauge rewarder
    /// @param tokenId The ID of the NFT position
    /// @return The timestamp of the last modification (0 if never modified)
    function positionLastModified(uint256 tokenId) external view returns (uint32);
    
    /// @notice Claims gauge rewards from liquidity incentives for a specific tokenId
    /// @dev Made payable to support multicall operations with ETH
    /// @param tokenId The ID of the token to claim rewards from
    /// @param tokens an array of reward tokens to claim
    function getReward(uint256 tokenId, address[] calldata tokens) external payable;
    
    /// @notice Claims gauge rewards for a specific period
    /// @dev Allows users to claim rewards for specific periods when they have accumulated many unclaimed periods
    /// @dev Made payable to support multicall operations with ETH
    /// @param period The specific period to claim rewards for (must be <= current period)
    /// @param tokenId The ID of the token to claim rewards from  
    /// @param tokens Array of reward tokens to claim
    /// @param receiver The address to send the rewards to
    function getPeriodReward(
        uint256 period,
        uint256 tokenId,
        address[] calldata tokens,
        address receiver
    ) external payable;
}
