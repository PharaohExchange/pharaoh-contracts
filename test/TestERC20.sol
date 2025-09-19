// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract TestERC20 is IERC20 {
    mapping(address => uint256) public override balanceOf;
    mapping(address => mapping(address => uint256)) public override allowance;
    
    uint256 public override totalSupply;
    string public name;
    string public symbol;
    uint8 public decimals = 18;

    constructor(uint256 amountToMint) {
        name = "Test Token";
        symbol = "TEST";
        mint(msg.sender, amountToMint);
    }

    function mint(address to, uint256 amount) public {
        uint256 balanceNext = balanceOf[to] + amount;
        require(balanceNext >= amount, 'overflow balance');
        balanceOf[to] = balanceNext;
        totalSupply += amount;
        emit Transfer(address(0), to, amount);
    }

    function transfer(address recipient, uint256 amount) external override returns (bool) {
        uint256 balanceBefore = balanceOf[msg.sender];
        require(balanceBefore >= amount, 'insufficient balance');
        balanceOf[msg.sender] = balanceBefore - amount;

        uint256 balanceRecipient = balanceOf[recipient];
        require(balanceRecipient + amount >= balanceRecipient, 'recipient balance overflow');
        balanceOf[recipient] = balanceRecipient + amount;

        emit Transfer(msg.sender, recipient, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external override returns (bool) {
        uint256 allowanceBefore = allowance[sender][msg.sender];
        require(allowanceBefore >= amount, 'allowance insufficient');

        allowance[sender][msg.sender] = allowanceBefore - amount;

        uint256 balanceBefore = balanceOf[sender];
        require(balanceBefore >= amount, 'insufficient balance');
        balanceOf[sender] = balanceBefore - amount;

        uint256 balanceRecipient = balanceOf[recipient];
        require(balanceRecipient + amount >= balanceRecipient, 'overflow balance recipient');
        balanceOf[recipient] = balanceRecipient + amount;

        emit Transfer(sender, recipient, amount);
        return true;
    }
} 