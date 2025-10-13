// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import {IVoteModule} from "./interfaces/IVoteModule.sol";
import {Errors} from "./libraries/Errors.sol";
import {IVoter} from "./interfaces/IVoter.sol";
import {IXPhar} from "./interfaces/IXPhar.sol";

contract VoteModule is IVoteModule, ReentrancyGuard, Initializable {
    /// @inheritdoc IVoteModule
    address public accessHub;
    /// @inheritdoc IVoteModule
    address public xPhar;
    /// @inheritdoc IVoteModule
    address public voter;
    /// @notice xPHAR token
    IXPhar public stakingToken;
    /// @notice underlying PHAR token
    IERC20 public underlying;

    /// @inheritdoc IVoteModule
    uint256 public cooldown = 12 hours;

    /// @inheritdoc IVoteModule
    uint256 public totalSupply;
    /// @inheritdoc IVoteModule
    uint256 public unlockTime;

    /// @inheritdoc IVoteModule
    mapping(address user => uint256 amount) public balanceOf;
    /// @inheritdoc IVoteModule
    mapping(address delegator => address delegatee) public delegates;
    /// @inheritdoc IVoteModule
    mapping(address owner => address operator) public admins;
    /// @inheritdoc IVoteModule
    mapping(address user => bool exempt) public cooldownExempt;

    modifier onlyAccessHub() {
        /// @dev ensure it is the accessHub
        require(msg.sender == accessHub, Errors.NOT_ACCESSHUB());
        _;
    }

    constructor() {
        voter = msg.sender;
    }

    function initialize(address _xPhar, address _voter, address _accessHub) external initializer {
        /// @dev making sure who deployed calls initialize
        require(voter == msg.sender, Errors.UNAUTHORIZED());
        require(_accessHub != address(0), Errors.INVALID_ADDRESS());
        require(_xPhar != address(0), Errors.INVALID_ADDRESS());
        require(_voter != address(0), Errors.INVALID_ADDRESS());
        xPhar = _xPhar;
        voter = _voter;
        accessHub = _accessHub;
        stakingToken = IXPhar(_xPhar);
        underlying = IERC20(IXPhar(_xPhar).PHAR());
    }

    /// @inheritdoc IVoteModule
    function depositAll() external {
        deposit(IERC20(xPhar).balanceOf(msg.sender));
    }

    /// @inheritdoc IVoteModule
    function deposit(uint256 amount) public nonReentrant {
        /// @dev ensure the amount is > 0
        require(amount != 0, Errors.ZERO_AMOUNT());
        /// @dev if the caller is not exempt
        if (!cooldownExempt[msg.sender]) {
            /// @dev block interactions during the cooldown period
            require(block.timestamp >= unlockTime, Errors.COOLDOWN_ACTIVE());
        }
        /// @dev transfer xPHAR in
        IERC20(xPhar).transferFrom(msg.sender, address(this), amount);
        /// @dev update accounting
        totalSupply += amount;
        balanceOf[msg.sender] += amount;

        /// @dev update data
        IVoter(voter).poke(msg.sender);

        emit Deposit(msg.sender, amount);
    }

    /// @inheritdoc IVoteModule
    function withdrawAll() external {
        /// @dev fetch stored balance
        uint256 _amount = balanceOf[msg.sender];
        /// @dev withdraw the stored balance
        withdraw(_amount);
    }

    /// @inheritdoc IVoteModule
    function withdraw(uint256 amount) public nonReentrant {
        /// @dev ensure the amount is > 0
        require(amount != 0, Errors.ZERO_AMOUNT());
        /// @dev if the caller is not exempt
        if (!cooldownExempt[msg.sender]) {
            /// @dev block interactions during the cooldown period
            require(block.timestamp >= unlockTime, Errors.COOLDOWN_ACTIVE());
        }

        /// @dev reduce total "supply"
        totalSupply -= amount;
        /// @dev decrement from balance mapping
        balanceOf[msg.sender] -= amount;
        /// @dev transfer the xPHAR to the caller
        IERC20(xPhar).transfer(msg.sender, amount);

        /// @dev update data via poke
        /// @dev we check in voter that msg.sender is the VoteModule
        IVoter(voter).poke(msg.sender);

        emit Withdraw(msg.sender, amount);
    }

    /// @inheritdoc IVoteModule
    /// @dev this is ONLY callable by xPHAR, which has important safety checks
    function notifyRewardAmount(uint256 amount) external nonReentrant {
        /// @dev only callable by xPhar contract
        require(msg.sender == xPhar, Errors.NOT_XRAM());
        require(amount == 0, "Rebases do not exist");

        /// @dev the timestamp of when people can withdraw next
        /// @dev not DoSable because only xPHAR can notify
        unlockTime = cooldown + block.timestamp;

        emit NotifyReward(msg.sender, 0);
    }

    /**
     * AccessHub Gated Functions
     */
    /// @inheritdoc IVoteModule
    function setCooldownExemption(address _user, bool _exempt) external onlyAccessHub {
        /// @dev ensure the call is not the same status
        require(cooldownExempt[_user] != _exempt, Errors.NO_CHANGE());
        /// @dev adjust the exemption status
        cooldownExempt[_user] = _exempt;

        emit ExemptedFromCooldown(_user, _exempt);
    }

    /// @inheritdoc IVoteModule
    function setNewCooldown(uint256 _cooldownInSeconds) external onlyAccessHub {
        /// @dev safety check
        require(_cooldownInSeconds <= 7 days);
        uint256 oldCooldown = cooldown;
        cooldown = _cooldownInSeconds;

        emit NewCooldown(oldCooldown, cooldown);
    }

    /**
     * User Management Functions
     */

    /// @inheritdoc IVoteModule
    function delegate(address delegatee) external {
        bool _isAdded = false;
        /// @dev if there exists a delegate, and the chosen delegate is the zero address
        if (delegatee == address(0) && delegates[msg.sender] != address(0)) {
            /// @dev delete the mapping
            delete delegates[msg.sender];
        } else {
            /// @dev else update delegation
            delegates[msg.sender] = delegatee;
            /// @dev flip to true if a delegate is written
            _isAdded = true;
        }
        /// @dev emit event
        emit Delegate(msg.sender, delegatee, _isAdded);
    }

    /// @inheritdoc IVoteModule
    function setAdmin(address admin) external {
        /// @dev visibility setting to false, even though default is false
        bool _isAdded = false;
        /// @dev if there exists an admin and the zero address is chosen
        if (admin == address(0) && admins[msg.sender] != address(0)) {
            /// @dev wipe mapping
            delete admins[msg.sender];
        } else {
            /// @dev else update mapping
            admins[msg.sender] = admin;
            /// @dev flip to true if an admin is written
            _isAdded = true;
        }
        /// @dev emit event
        emit SetAdmin(msg.sender, admin, _isAdded);
    }

    /**
     * View Functions
     */

    /// @inheritdoc IVoteModule
    function getPeriod() public view returns (uint256) {
        return (block.timestamp / 1 weeks);
    }

    /// @inheritdoc IVoteModule
    function isDelegateFor(address caller, address owner) external view returns (bool approved) {
        /// @dev check the delegate mapping AND admin mapping due to hierarchy (admin > delegate)
        return (
            delegates[owner] == caller || admins[owner] == caller
            /// @dev return true if caller is the owner as well
            || caller == owner
            /// @dev return true if caller is the accessHub as well
            || caller == accessHub
        );
    }

    /// @inheritdoc IVoteModule
    function isAdminFor(address caller, address owner) external view returns (bool approved) {
        /// @dev return whether the caller is the address in the map
        /// @dev return true if caller is the owner as well
        return (admins[owner] == caller || caller == owner);
    }
}
