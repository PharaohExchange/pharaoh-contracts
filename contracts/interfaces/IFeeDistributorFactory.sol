// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

interface IFeeDistributorFactory {
    function createFeeDistributor(address pairFees) external returns (address);
}
