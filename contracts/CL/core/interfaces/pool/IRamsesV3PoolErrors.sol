// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title Errors emitted by a pool
/// @notice Contains all custom errors that can be emitted by the pool
interface IRamsesV3PoolErrors {
    /*//////////////////////////////////////////////////////////////
                            POOL ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when the pool is locked during a swap or mint/burn operation
    error LOK(); // Locked

    /// @notice Thrown when tick lower is greater than upper in position management
    error TLU(); // Tick Lower > Upper

    /// @notice Thrown when tick lower is less than minimum allowed
    error TLM(); // Tick Lower < Min

    /// @notice Thrown when tick upper is greater than maximum allowed
    error TUM(); // Tick Upper > Max

    /// @notice Thrown when the pool is already initialized
    error AI(); // Already Initialized

    /// @notice Thrown when the first margin value is zero
    error M0(); // Mint token 0 error

    /// @notice Thrown when the second margin value is zero
    error M1(); // Mint token1 error

    /// @notice Thrown when amount specified is invalid
    error AS(); // Amount Specified Invalid

    /// @notice Thrown when input amount is insufficient
    error IIA(); // Insufficient Input Amount

    /// @notice Thrown when pool lacks sufficient liquidity for operation
    error L(); // Insufficient Liquidity

    /// @notice Thrown when the first fee value is zero
    error F0(); // Fee0 issue or Fee = 0

    /// @notice Thrown when the second fee value is zero
    error F1(); // Fee1 issue

    /// @notice Thrown when square price limit is invalid
    error SPL(); // Square Price Limit Invalid
}
