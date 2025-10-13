// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Extended} from "./IERC20Extended.sol";
import {IVoter} from "./IVoter.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

interface IXPhar is IERC20 {
    event InstantExit(address indexed user, uint256);
    event XRamRedeemed(address indexed user, uint256);
    event Converted(address indexed user, uint256);

    event Exemption(address indexed candidate, bool status, bool success);

    event NewOperator(address indexed o, address indexed n);

    event Rebase(address indexed caller, uint256 amount);

    /// @notice address of the phar token
    function PHAR() external view returns (IERC20Extended);

    /// @notice address of the voter
    function VOTER() external view returns (IVoter);

    function MINTER() external view returns (address);

    function ACCESS_HUB() external view returns (address);

    /// @notice address of the operator
    function operator() external view returns (address);

    /// @notice address of the VoteModule
    function VOTE_MODULE() external view returns (address);

    /// @notice max slashing amount
    function SLASHING_PENALTY() external view returns (uint256);

    /// @notice denominator
    function BASIS() external view returns (uint256);

    function phar() external view returns (address);

    /// @notice the last period rebases were distributed
    function lastDistributedPeriod() external view returns (uint256);

    /// @notice amount of burns in total
    function totalBurned() external view returns (uint256);

    /// @notice pauses the contract
    function pause() external;

    /// @notice unpauses the contract
    function unpause() external;

    /**
     *
     */
    // General use functions
    /**
     *
     */

    /// @dev mints xPHAR for each phar.
    function convertEmissionsToken(uint256 _amount) external;

    /// @notice function called by the minter to send the rebases once a week
    function rebase() external;
    /**
     * @dev exit instantly with a penalty
     * @param _amount amount of xPHAR to exit
     */
    function exit(uint256 _amount) external returns (uint256 _exitedAmount);

    /**
     *
     */
    // Permissioned functions, timelock/operator gated
    /**
     *
     */

    /// @dev allows rescue of any non-stake token
    function rescueTrappedTokens(address[] calldata _tokens, uint256[] calldata _amounts) external;

    /// @notice migrates the operator to another contract
    function migrateOperator(address _operator) external;

    /// @notice set exemption status for an address
    function setExemption(address[] calldata _exemptee, bool[] calldata _exempt) external;

    function setExemptionTo(address[] calldata _exemptee, bool[] calldata _exempt) external;

    /**
     *
     */
    // Getter functions
    /**
     *
     */

    /// @notice returns the amount of PHAR within the contract
    function getBalanceResiding() external view returns (uint256);

    /// @notice whether the address is exempt
    /// @param _who who to check
    /// @return _exempt whether it's exempt
    function isExempt(address _who) external view returns (bool _exempt);

    /// @notice whether the address is exempt to
    /// @param _who who to check
    /// @return _exempt whether it's exempt
    function isExemptTo(address _who) external view returns (bool _exempt);
}
