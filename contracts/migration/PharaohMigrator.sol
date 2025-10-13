// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IVePHAR is IERC721 {
    function locked(uint256 tokenId) external view returns (int128 amount, uint256 end);
}

contract PharaohMigrator is Ownable, ReentrancyGuard {
    /// @notice the vePHAR contract address
    IVePHAR public constant VE_PHAR = IVePHAR(0xAAAEa1fB9f3DE3F70E89f37B69Ab11B47eb9Ce6F);
    /// @notice the old Pharaoh token contract address
    IERC20 public constant PHAR = IERC20(0xAAAB9D12A30504559b0C5a9A5977fEE4A6081c6b);
    
    /// @dev we give xPHAR transfer whitelist to this contract
    /// @notice the xPHAR contract address (vePHAR's replacement)
    IERC20 public xPhar;
    /// @notice the new Pharaoh token contract in V3
    IERC20 public pharNew;

    /// @notice the end time of the migration
    uint256 public endTime;
    /// @notice the total amount of vePHAR migrated
    uint256 public totalMigrated;
    /// @notice whether the migration is closed
    bool public closed;

    /// @notice event emitted when vePHAR is migrated
    event MigratedVe(address indexed user, uint256 tokenID, uint256 amount);
    /// @notice event emitted when PHAR is migrated
    event MigratedPhar(address indexed user, uint256 amount);
    /// @notice event emitted when the timer starts
    event TimerStarted(uint256 startTime, uint256 endTime);

    /// @notice modifier to check if the migration is closed and the addresses are initialized
    modifier check() {
        require(!closed, "migration is closed");
        /// @dev check if the xPhar address is initialized
        require(address(xPhar) != address(0) && address(pharNew) != address(0), "addresses not initialized");
        /// @dev check if the migration is closed
        if (block.timestamp > endTime) {
            _shutDown();
        }
        _;
    }

    constructor(address _owner) Ownable(_owner) {
    }

    /// @custom:important the user's vePHAR MUST be reset/unattached from all gauges/voter to be able to migrate without errors.
    /// @notice migrate the vePHAR to xPHAR
    /// @param _tokenID the token ID of the vePHAR to migrate
    function migrateVe(uint256 _tokenID) external check nonReentrant {
        VE_PHAR.transferFrom(msg.sender, address(this), _tokenID);
        require(VE_PHAR.ownerOf(_tokenID) == address(this), "error transferring vePHAR ownership");
        (int128 amount, ) = VE_PHAR.locked(_tokenID);
        /// @dev locked values cannot be a negative so we do not validate the sign
        uint256 amountToMigrate = uint256(uint128(amount));
        /// @dev vePHAR --> xPHAR
        if(amountToMigrate > 0) {
            xPhar.transfer(msg.sender, amountToMigrate);
            /// @dev increment the amount thats been migrated
            totalMigrated += amountToMigrate;
            emit MigratedVe(msg.sender, _tokenID, amountToMigrate);
        }
        // no op
    }

    /// @notice simple conversion of old PHAR to new PHAR 1:1
    /// @param _amount the amount of PHAR to convert
    function convertPhar(uint256 _amount) external check nonReentrant {
        require(_amount > 0, "amount must be greater than 0");
        uint256 amount = _amount;
        // PHAR --> new PHAR
        PHAR.transferFrom(msg.sender, address(this), amount);
        /// @dev new PHAR --> user
        pharNew.transfer(msg.sender, amount);
        /// @dev increment the amount thats been migrated
        totalMigrated += amount;
        /// @dev emit the event
        emit MigratedPhar(msg.sender, amount);
    }


    /// @notice set the addresses and start the timer
    /// @param _xPhar the address of the xPHAR contract
    /// @param _pharNew the address of the new Pharaoh token contract
    function setAddressesAndStart(address _xPhar, address _pharNew) external onlyOwner {
        /// @dev check if the xPhar address is already set to prevent any issues
        require(address(xPhar) == address(0) && address(pharNew) == address(0), "values already set");
        /// @dev set the xPHAR contract address
        xPhar = IERC20(_xPhar);
        /// @dev set the new Pharaoh token contract address
        pharNew = IERC20(_pharNew);
        /// @dev set the end time to 1 year from initialization of the addresses on the contract
        endTime = block.timestamp + 365 days;
        /// @dev emit the event
        emit TimerStarted(block.timestamp, endTime);
    }

    /// @dev rescue function to rescue any tokens that are sent to the contract
    /// @param _token the address of the token to rescue
    /// @param _to the address to send the tokens to
    /// @param _amount the amount of tokens to rescue
    function rescue(address _token, address _to, uint256 _amount) external onlyOwner {
        /// @dev transfer the tokens to the address
        IERC20(_token).transfer(_to, _amount);
    }

    /// @notice rescue function to rescue any vePHAR
    /// @param _tokenId the token ID of the vePHAR to rescue
    function rescueVePHAR(uint256 _tokenId) external onlyOwner {
        /// @dev transfer the vePHAR to the owner
        VE_PHAR.transferFrom(address(this), owner(), _tokenId);
    }

    /// @dev last resort backstop
    /// @param x the address of the contract to call
    /// @param _x the data to send to the contract
    function safetyNet(address x, bytes calldata _x) external onlyOwner {
        /// @dev call the contract
        (bool success,) = x.call(_x);
        require(success);
    }

    /// @dev end the migration
    function _shutDown() private {
        closed = true;
        /// @dev get the remaining balance of the xPHAR contract
        uint256 remainingBalance = xPhar.balanceOf(address(this));
        if (remainingBalance > 0) {
            xPhar.transfer(owner(), remainingBalance);
        }
        /// @dev get the remaining balance of the new Pharaoh token contract
        remainingBalance = pharNew.balanceOf(address(this));
        if (remainingBalance > 0) {
            pharNew.transfer(owner(), remainingBalance);
        }
        /// @dev get the remaining balance of the old Pharaoh token contract
        remainingBalance = PHAR.balanceOf(address(this));
        if (remainingBalance > 0) {
            PHAR.transfer(owner(), remainingBalance);
        }
    }
}
