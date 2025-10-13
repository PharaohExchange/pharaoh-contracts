// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.26;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {IERC20Extended} from "./interfaces/IERC20Extended.sol";
import {IMinter} from "./interfaces/IMinter.sol";
import {IVoter} from "./interfaces/IVoter.sol";
import {Errors} from "./libraries/Errors.sol";

/// @title Minter contract for Pharaoh
/// @custom:description Immutable minter contract for Pharaoh that permits codified weekly emissions
/// @custom:info Emissions can be adjusted a max of 25% in either direction per epoch
contract Minter is IMinter {
    /// @notice emissions value
    uint256 public weeklyEmissions;
    /// @notice controls emissions growth or decay
    uint256 public emissionsMultiplier;
    /// @notice unix timestamp of the first period
    uint256 public firstPeriod;
    /// @notice currently active unix timestamp of epoch start
    uint256 public activePeriod;
    /// @notice the last period the emissions multiplier was updated
    uint256 public lastMultiplierUpdate;

    /// @notice basis invariant 10_000 = 100%
    uint256 public constant BASIS = 10_000;
    /// @notice max deviation of 25% per epoch (for epochs >= 3)
    uint256 public constant MAX_DEVIATION = 2_500;
    /// @notice max deviation of 100% per epoch (for epochs < 3)
    uint256 public constant EARLY_EPOCH_MAX_DEVIATION = 10_000;
    /// @notice initial supply of 750m PHAR
    uint256 public constant INITIAL_SUPPLY = 750_000_000 * 1e18;
    /// @notice max supply of 1b PHAR
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 1e18;

    /// @notice current operator
    address public operator;
    /// @notice the access control center
    address public accessHub;
    /// @notice xPHAR contract address
    address public xPhar;
    /// @notice central voter contract
    address public voter;
    /// @notice the IERC20 version of PHAR
    IERC20Extended public phar;

    modifier onlyGovernance() {
        require(msg.sender == accessHub, Errors.NOT_AUTHORIZED(msg.sender));
        _;
    }

    constructor(address _accessHub, address _operator) {
        accessHub = _accessHub;
        operator = _operator;
    }

    /// @inheritdoc IMinter
    function kickoff(
        address _rex,
        address _voter,
        uint256 _initialWeeklyEmissions,
        uint256 _initialMultiplier,
        address _xPhar
    ) external {
        /// @dev ensure only the operator can kickoff the minter
        require(msg.sender == operator, Errors.NOT_AUTHORIZED(msg.sender));
        /// @dev ensure the emissions token isn't set yet
        require(address(phar) == address(0), Errors.STARTED());
        require(_xPhar != address(0), Errors.INVALID_CONTRACT());
        require(_voter != address(0), Errors.INVALID_CONTRACT());
        require(_rex != address(0), Errors.INVALID_CONTRACT());
        phar = IERC20Extended(_rex);
        xPhar = _xPhar;
        voter = _voter;
        /// @dev starting emissions
        weeklyEmissions = _initialWeeklyEmissions;
        /// @dev init emissionsMultiplier
        emissionsMultiplier = _initialMultiplier;
        emit SetVoter(_voter);
        phar.mint(operator, INITIAL_SUPPLY);
    }

    /// @inheritdoc IMinter
    function updatePeriod() public returns (uint256 period) {
        require(firstPeriod != 0, Errors.EMISSIONS_NOT_STARTED());
        /// @dev set period equal to the current activePeriod
        period = activePeriod;
        /// @dev if >= Thursday 0 UTC
        if (getPeriod() > period) {
            /// @dev fetch the current period
            period = getPeriod();
            /// @dev set the active period to the new period
            activePeriod = period;
            /// @dev calculate the weekly emissions
            uint256 _weeklyEmissions = calculateWeeklyEmissions();
            /// @dev set global value to the above calculated emissions
            weeklyEmissions = _weeklyEmissions;
            /// @dev if supply cap was not already hit
            if (weeklyEmissions > 0) {
                /// @dev mint emissions to the Minter contract
                phar.mint(address(this), _weeklyEmissions);
                /// @dev approvals for phar on voter
                phar.approve(voter, _weeklyEmissions);
                /// @dev notify emissions to the voter contract
                IVoter(voter).notifyRewardAmount(_weeklyEmissions);
                /// @dev emit the weekly emissions minted
                emit Mint(msg.sender, _weeklyEmissions);
            }
        }
    }

    function rebase() public {
        /// @dev fetch the data from encoding
        bytes memory data = abi.encodeWithSignature("rebase()");
        /// @dev call the rebase function
        (bool success,) = xPhar.call(data);
        require(success, "REBASE_UNSUCCESSFUL");
    }

    function updatePeriodAndRebase() external {
        updatePeriod();
        rebase();
    }

    /// @inheritdoc IMinter
    function initEpoch0() external {
        /// @dev ensure only the operator can start the emissions
        require(msg.sender == operator, Errors.NOT_AUTHORIZED(msg.sender));
        /// @dev ensure epoch 0 has not started yet
        require(firstPeriod == 0, Errors.STARTED());
        /// @dev set the active period to the current
        activePeriod = getPeriod();
        /// @dev set the last update as the last period so emissions can be updated once if needed
        lastMultiplierUpdate = activePeriod - 1;
        /// @dev set the first period to the active period
        firstPeriod = activePeriod;
        /// @dev mints the epoch 0 emissions for manual distribution
        phar.mint(operator, weeklyEmissions);
    }

    /// @inheritdoc IMinter
    /// @notice Adjusts emissions by a basis points change
    /// @param _basisPointsChange The basis points to change emissions by (-2500 = -25%, +2500 = +25%)
    /// @dev For epochs < 3: Bounded to ±EARLY_EPOCH_MAX_DEVIATION (10000 = 100%)
    /// @dev For epochs >= 3: Bounded to ±MAX_DEVIATION (2500 = 25%)
    function adjustEmissions(int256 _basisPointsChange) external onlyGovernance {
        /// @dev ensure that the last time the multiplier was updated was not the same period
        require(lastMultiplierUpdate != activePeriod, Errors.SAME_PERIOD());
        
        /// @dev determine max allowed deviation based on current epoch
        uint256 maxAllowedDeviation = getEpoch() < 3 ? EARLY_EPOCH_MAX_DEVIATION : MAX_DEVIATION;
        
        /// @dev ensure change is within bounds
        require(_basisPointsChange >= -int256(maxAllowedDeviation) && _basisPointsChange <= int256(maxAllowedDeviation), Errors.TOO_HIGH());
        require(_basisPointsChange != 0, Errors.NO_CHANGE());
        
        /// @dev set the last update to the current period
        lastMultiplierUpdate = activePeriod;
        
        /// @dev adjust the current multiplier by the percentage
        uint256 newMultiplier = (emissionsMultiplier * uint256(int256(BASIS) + _basisPointsChange)) / BASIS;
        
        /// @dev prevent multiplier from going to 0 (would brick emissions forever since % of 0 = 0)
        require(newMultiplier > 0, Errors.ZERO());
        
        /// @dev set new values
        emissionsMultiplier = newMultiplier;
        
        emit EmissionsMultiplierUpdated(newMultiplier);
    }

    /// @inheritdoc IMinter
    function calculateWeeklyEmissions() public view returns (uint256) {
        /// @dev fetch proposed emissions
        uint256 _weeklyEmissions = (weeklyEmissions * emissionsMultiplier) / BASIS;
        /// @dev if it's zero
        if (_weeklyEmissions == 0) return 0;
        /// @dev if minting goes over the max supply
        if (phar.totalSupply() + _weeklyEmissions > MAX_SUPPLY) {
            /// @dev update value to difference
            _weeklyEmissions = MAX_SUPPLY - phar.totalSupply();
        }
        return _weeklyEmissions;
    }

    /// @inheritdoc IMinter
    function getPeriod() public view returns (uint256 period) {
        period = block.timestamp / 1 weeks;
    }

    /// @inheritdoc IMinter
    function getEpoch() public view returns (uint256 _epoch) {
        return getPeriod() - firstPeriod;
    }
}
