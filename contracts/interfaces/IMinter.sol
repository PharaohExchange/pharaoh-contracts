// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

interface IMinter {
    event SetVeDist(address _value);
    event SetVoter(address _value);
    event Mint(address indexed sender, uint256 weekly);
    event RebaseUnsuccessful(uint256 _current, uint256 _currentPeriod);
    event EmissionsMultiplierUpdated(uint256 _emissionsMultiplier);

    /// @notice decay or inflation scaled to 10_000 = 100%
    /// @return _multiplier the emissions multiplier
    function emissionsMultiplier() external view returns (uint256 _multiplier);

    /// @notice unix timestamp of current epoch's start
    /// @return _activePeriod the active period
    function activePeriod() external view returns (uint256 _activePeriod);

    /// @notice update the epoch (period) -- callable once a week at >= Thursday 0 UTC
    /// @return period the new period
    function updatePeriod() external returns (uint256 period);

    /// @notice intialize epoch0 + emissions (immediately active for this week)
    function initEpoch0() external;

    /// @notice adjusts emissions by a basis points change
    /// @param _basisPointsChange The basis points to change emissions by
    /// @dev For epochs < 3: Bounded to ±10000 (±100%)
    /// @dev For epochs >= 3: Bounded to ±2500 (±25%)
    function adjustEmissions(int256 _basisPointsChange) external;

    /// @notice calculates the emissions to be sent to the voter
    /// @return _weeklyEmissions the amount of emissions for the week
    function calculateWeeklyEmissions() external view returns (uint256 _weeklyEmissions);

    /// @notice kicks off the initial minting and variable declarations
    function kickoff(
        address _rex,
        address _voter,
        uint256 _initialWeeklyEmissions,
        uint256 _initialMultiplier,
        address _xPhar
    ) external;

    /// @notice returns (block.timestamp / 1 week) for gauge use
    /// @return period period number
    function getPeriod() external view returns (uint256 period);

    /// @notice returns the numerical value of the current epoch
    /// @return _epoch epoch number
    function getEpoch() external view returns (uint256 _epoch);
}
