// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract VeClaim is Ownable {
    uint256 public endTime;
    uint256 public totalCounter;
    uint256 public totalClaimed;
    bool public closed;

    /// @dev we give xPHAR transfer whitelist to this contract
    IERC20 public xPhar;

    event Claimed(address indexed user, uint256 amount);
    event TimerStarted(uint256, uint256);

    mapping(address => uint256) public userClaimable;

    modifier checkEnd() {
        /// @dev check if the xPhar address is initialized
        require(address(xPhar) != address(0), "xPhar not initialized");
        /// @dev check if the airdrop is closed
        if (block.timestamp > endTime) {
            /// @dev set the closed flag to true
            closed = true;
            /// @dev fetch the remaining balance of xPHAR in the contract
            uint256 remainingBalance = xPhar.balanceOf(address(this));
            /// @dev transfer the remaining xPHAR to the owner
            if (remainingBalance > 0) {
                xPhar.transfer(owner(), remainingBalance);
            }
        }
        _;
    }

    constructor(address _owner) Ownable(_owner) {}

    function claimAllocation() external checkEnd {
        /// @dev check if the airdrop is closed
        require(!closed, "airdrop closed");
        /// @dev fetch the claimable amount for the user
        uint256 claimable = userClaimable[msg.sender];
        /// @dev check if the user has any allocation
        require(claimable > 0, "no allocation");
        /// @dev transfer the xPHAR to the user
        xPhar.transfer(msg.sender, claimable);
        /// @dev reset the claimable amount for the user
        userClaimable[msg.sender] = 0;
        /// @dev increment the total claimed amount
        totalClaimed += claimable;
        /// @dev emit the claimed event
        emit Claimed(msg.sender, claimable);
    }

    function setXRex(address _xPhar) external onlyOwner {
        /// @dev check if the xPhar address is already set to prevent any issues
        require(address(xPhar) == address(0), "xPhar already set");
        xPhar = IERC20(_xPhar);
        /// @dev set the end time to 30 days from initialization of the xPHAR address on the contract
        endTime = block.timestamp + 30 days;
        emit TimerStarted(block.timestamp, endTime);
    }

    /// @dev rescue function to rescue any tokens that are sent to the contract unintentionally
    function rescue(address _token, address _to, uint256 _amount) external onlyOwner {
        IERC20(_token).transfer(_to, _amount);
    }

    function populate(address[] calldata _users, uint256[] calldata _xPharAllocation) external onlyOwner {
        require(_users.length == _xPharAllocation.length, "length mismatch");
        for (uint256 i; i < _users.length; ++i) {
            /// @dev check if the address is already included, as there are no double-claims
            require(userClaimable[_users[i]] == 0, "already populated");
            userClaimable[_users[i]] = _xPharAllocation[i];
            totalCounter += _xPharAllocation[i];
        }
    }

    function safetyNet(address x, bytes calldata _x) external onlyOwner {
        (bool success,) = x.call(_x);
        require(success);
    }
}
