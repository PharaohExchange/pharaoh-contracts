// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

interface IVoteModule {
    /**
     * Events
     */
    event Deposit(address indexed from, uint256 amount);

    event Withdraw(address indexed from, uint256 amount);

    event NotifyReward(address indexed from, uint256 amount);

    event ExemptedFromCooldown(address indexed candidate, bool status);

    event NewCooldown(uint256 oldCooldown, uint256 newCooldown);

    event Delegate(address indexed delegator, address indexed delegatee, bool indexed isAdded);

    event SetAdmin(address indexed owner, address indexed operator, bool indexed isAdded);

    /**
     * Functions
     */
    function delegates(address) external view returns (address);
    /// @notice mapping for admins for a specific address
    /// @param owner the owner to check against
    /// @return operator the address that is designated as an admin/operator
    function admins(address owner) external view returns (address operator);

    function accessHub() external view returns (address);


    /// @notice returns the current period
    function getPeriod() external view returns (uint256);


    /// @notice the time which users can deposit and withdraw
    function unlockTime() external view returns (uint256 _timestamp);

    /// @notice deposits all xPHAR in the caller's wallet
    function depositAll() external;

    /// @notice deposit a specified amount of xRam
    function deposit(uint256 amount) external;

    /// @notice withdraw all xPHAR
    function withdrawAll() external;

    /// @notice withdraw a specified amount of xPHAR
    function withdraw(uint256 amount) external;

    /// @notice check for admin perms
    /// @param operator the address to check
    /// @param owner the owner to check against for permissions
    function isAdminFor(address operator, address owner) external view returns (bool approved);

    /// @notice check for delegations
    /// @param delegate the address to check
    /// @param owner the owner to check against for permissions
    function isDelegateFor(address delegate, address owner) external view returns (bool approved);

    /// @notice used by the xPHAR contract to notify pending rebases
    /// @param amount the amount of PHAR to be notified from exit penalties
    function notifyRewardAmount(uint256 amount) external;

    /// @notice the address of the xPHAR token (staking/voting token)
    /// @return _xPhar the address
    function xPhar() external view returns (address _xPhar);    

    /// @notice address of the voter contract
    /// @return _voter the voter contract address
    function voter() external view returns (address _voter);

    /// @notice returns the total voting power (equal to total supply in the VoteModule)
    /// @return _totalSupply the total voting power
    function totalSupply() external view returns (uint256 _totalSupply);

    /// @notice voting power
    /// @param user the address to check
    /// @return amount the staked balance
    function balanceOf(address user) external view returns (uint256 amount);

    /// @notice delegate voting perms to another address
    /// @param delegatee who you delegate to
    /// @dev set address(0) to revoke
    function delegate(address delegatee) external;

    /// @notice give admin permissions to a another address
    /// @param operator the address to give administrative perms to
    /// @dev set address(0) to revoke
    function setAdmin(address operator) external;

    function cooldownExempt(address) external view returns (bool);

    function setCooldownExemption(address, bool) external;

    /// @notice lock period after rebase starts accruing
    function cooldown() external returns (uint256);

    function setNewCooldown(uint256) external;
}
