// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {IRamsesV3Factory} from "../../core/interfaces/IRamsesV3Factory.sol";
import {IRamsesV3Pool} from "../../core/interfaces/IRamsesV3Pool.sol";
import {IRamsesV3PoolDeployer} from "../../core/interfaces/IRamsesV3PoolDeployer.sol";

import {PeripheryImmutableState} from "./PeripheryImmutableState.sol";
import {IPoolInitializer} from "../interfaces/IPoolInitializer.sol";

/// @title Creates and initializes V3 Pools
abstract contract PoolInitializer is IPoolInitializer, PeripheryImmutableState {
    /// @inheritdoc IPoolInitializer
    function createAndInitializePoolIfNecessary(address token0, address token1, int24 tickSpacing, uint160 sqrtPriceX96)
        external
        payable
        override
        returns (address pool)
    {
        require(token0 < token1);
        IRamsesV3Factory factory = IRamsesV3Factory(IRamsesV3PoolDeployer(deployer).RamsesV3Factory());
        pool = factory.getPool(token0, token1, tickSpacing);

        if (pool == address(0)) {
            pool = factory.createPool(token0, token1, tickSpacing, sqrtPriceX96);
        } else {
            (uint160 sqrtPriceX96Existing,,,,,,) = IRamsesV3Pool(pool).slot0();
            if (sqrtPriceX96Existing == 0) {
                IRamsesV3Pool(pool).initialize(sqrtPriceX96);
            }
        }
    }
}
