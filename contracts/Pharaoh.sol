// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

/// @title token contract for Pharaoh
/// @dev standard mintable ERC20 built for vote-governance emissions
contract Pharaoh is ERC20, ERC20Burnable, ERC20Permit {
    /// @notice minter contract address
    address public minter;

    /// @notice 1 billion max supply
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 1e18;

    constructor(
        address _minter
    ) ERC20("Pharaoh", "PHAR") ERC20Permit("Pharaoh") {
        minter = _minter;
    }

    /// @notice mint function called by minter weekly
    /// @param to the address to mint to
    /// @param amount amount of tokens
    function mint(address to, uint256 amount) public {
        require(msg.sender == minter, "NOT_MINTER");
        amount = (super.totalSupply() + amount > MAX_SUPPLY) ? MAX_SUPPLY - super.totalSupply() : amount;
        /// @dev if the max supply is not hit yet
        if (amount > 0) {
            _mint(to, amount);
        }
    }

    /// @notice set the minter after initial mint
    /// @dev functionality is given to the Minter.sol contract which controls weekly emissions programmatically
    /// @custom:immutability the minter is fully immutable and cannot mint tokens at will
    function setMinter(address _minter) public {
        require(msg.sender == minter, "NOT_MINTER");
        minter = _minter;
    }
}
