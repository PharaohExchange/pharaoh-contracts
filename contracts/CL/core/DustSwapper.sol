// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {LiquidityAmounts} from "contracts/CL/periphery/libraries/LiquidityAmounts.sol";

import {IVoter} from "contracts/interfaces/IVoter.sol";
import {IRamsesV3Pool, IRamsesV3PoolActions} from "contracts/CL/core/interfaces/IRamsesV3Pool.sol";
import {INonfungiblePositionManager} from "contracts/CL/periphery/interfaces/INonfungiblePositionManager.sol";

contract DustSwapper {
    using EnumerableSet for EnumerableSet.AddressSet;

    error Missing(address token0, address token1);

    address public immutable owner;
    IVoter immutable voter;
    INonfungiblePositionManager immutable nfpManager;

    int24 internal constant MIN_TICK = -887272;
    int24 internal constant MAX_TICK = -MIN_TICK;

    uint160 internal constant MIN_SQRT_RATIO = 4295128739;
    uint160 internal constant MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970342;

    EnumerableSet.AddressSet gauges;
    EnumerableSet.AddressSet clPools;

    mapping(address clPool => uint256 tokenId) public poolToNfp;

    bool isRunning;
    address _tempToken0;
    address _tempToken1;

    modifier running() {
        isRunning = true;
        _;
        isRunning = false;
    }

    modifier onlyRunning() {
        require(isRunning, "NotRunning");
        _;
    }

    modifier onlyOwner() {
        require(isRunning, "OnlyOwner");
        _;
    }

    constructor() {
        owner = msg.sender;
        voter = IVoter(0x3aF1dD7A2755201F8e2D6dCDA1a61d9f54838f4f);
        nfpManager = INonfungiblePositionManager(payable(0x12E66C8F215DdD5d48d150c8f46aD0c6fB0F4406));
    }

    function getAllGauges() external view returns (address[] memory) {
        return gauges.values();
    }

    function getGauge(uint256 index) external view returns (address) {
        return gauges.at(index);
    }

    function getGaugeLength() external view returns (uint256) {
        return gauges.length();
    }

    function getAllClPools() external view returns (address[] memory) {
        return clPools.values();
    }

    function getClPool(uint256 index) external view returns (address) {
        return clPools.at(index);
    }

    function getClPoolsLength() external view returns (uint256) {
        return clPools.length();
    }

    function updateRecords() public {
        address[] memory _gauges = voter.getAllGauges();

        // Check if there are more gauges than currently recorded
        uint256 oldLength = gauges.length();
        if (oldLength != _gauges.length) {
            uint256 index;
            for (index = oldLength; index < _gauges.length; index++) {
                // add to recorded gauges
                gauges.add(_gauges[index]);

                // add to clPools if CL
                if (voter.isClGauge(_gauges[index])) {
                    clPools.add(voter.poolForGauge(_gauges[index]));
                }
            }
        }
    }

    struct FailedSeed {
        address pool;
        address token0;
        address token1;
        uint256 amount0;
        uint256 amount1;
    }

    function seed(uint256 start, uint256 end) external returns (FailedSeed[] memory failedSeeds) {
        if (end > clPools.length()) {
            end = clPools.length();
        }

        failedSeeds = new FailedSeed[](end);
        uint256 failedLength;

        for (uint256 index = start; index < end; index++) {
            IRamsesV3Pool pool = IRamsesV3Pool(clPools.at(index));

            uint256 tokenId = poolToNfp[address(pool)];

            try nfpManager.ownerOf(tokenId) returns (address _owner) {
                if (_owner == address(this)) {
                    // go to next index if nfp exists and is owned by this contract
                    continue;
                }
            } catch (bytes memory) {
                // keep going and mint a position if ownerOf reverts
                // ownerOf reverts when the NFP no longer exists
            }

            address token0 = pool.token0();
            address token1 = pool.token1();

            (uint160 sqrtRatioX96,,,,,,) = pool.slot0();

            (uint256 amount0, uint256 amount1) =
                LiquidityAmounts.getAmountsForLiquidity(sqrtRatioX96, MIN_SQRT_RATIO, MAX_SQRT_RATIO, 1000);
            amount0 = (amount0 + 1);
            amount1 = (amount1 + 1);

            IERC20(token0).approve(address(nfpManager), amount0);
            IERC20(token1).approve(address(nfpManager), amount1);

            int24 tickSpacing = pool.tickSpacing();

            // mint and update nfp tokenId for pool
            try nfpManager.mint(
                INonfungiblePositionManager.MintParams({
                    token0: token0,
                    token1: token1,
                    tickSpacing: tickSpacing,
                    tickLower: MIN_TICK - (MIN_TICK % tickSpacing),
                    tickUpper: MAX_TICK - (MAX_TICK % tickSpacing),
                    amount0Desired: amount0,
                    amount1Desired: amount1,
                    amount0Min: 0,
                    amount1Min: 0,
                    recipient: address(this),
                    deadline: block.timestamp + 1
                })
            ) returns (uint256 _tokenId, uint128 _liquidity, uint256, uint256) {
                if (_liquidity > 0) {
                    tokenId = _tokenId;
                    poolToNfp[address(pool)] = tokenId;
                } else {
                    failedSeeds[failedLength] = FailedSeed({
                        pool: address(pool),
                        token0: token0,
                        token1: token1,
                        amount0: amount0,
                        amount1: amount1
                    });
                    failedLength++;
                }
            } catch (bytes memory) {
                failedSeeds[failedLength] = FailedSeed({
                    pool: address(pool),
                    token0: token0,
                    token1: token1,
                    amount0: amount0,
                    amount1: amount1
                });
                failedLength++;
            }
        }

        // trim length if needed
        if (failedLength != failedSeeds.length) {
            assembly ("memory-safe") {
                mstore(failedSeeds, failedLength)
            }
        }

        return failedSeeds;
    }

    // isn't view but you can call this with callStatic for viewing purposes
    function findMissing() external returns (address[] memory _missingTokens) {
        updateRecords();
        _missingTokens = new address[](clPools.length() * 2);

        uint256 missingLength;

        uint256 index;
        for (index = 0; index < clPools.length(); index++) {
            IRamsesV3Pool pool = IRamsesV3Pool(clPools.at(index));
            address token0 = pool.token0();
            address token1 = pool.token1();

            if (IERC20(token0).balanceOf(address(this)) == 0) {
                _missingTokens[missingLength] = token0;
                missingLength++;
            }
            if (IERC20(token1).balanceOf(address(this)) == 0) {
                _missingTokens[missingLength] = token1;
                missingLength++;
            }
        }

        // trim _missingTokens length if needed
        if (missingLength != _missingTokens.length) {
            assembly ("memory-safe") {
                mstore(_missingTokens, missingLength)
            }
        }
    }

    function swapDust(uint256 start, uint256 end, bool _updateRecords, bool force)
        public
        running
        returns (uint256[] memory, address[] memory)
    {
        if (block.timestamp > ((block.timestamp / (604800)) + 1) * 604800 - 3600 && !force) {
            revert("Time");
        }

        if (_updateRecords) {
            updateRecords();
        }

        if (end > clPools.length()) {
            end = clPools.length();
        }

        uint256 index;
        uint256 period = block.timestamp / (86400 * 7);
        uint256[] memory failedIndex = new uint256[](end - start);
        address[] memory failedPool = new address[](end - start);
        uint256 failedLength;
        bool didSwap;
        for (index = start; index < end; index++) {
            IRamsesV3Pool pool = IRamsesV3Pool(clPools.at(index));
            if (pool.lastPeriod() == period && !force) {
                continue;
            }
            address token0 = pool.token0();
            _tempToken0 = token0;
            _tempToken1 = pool.token1();

            bool zeroForOne = IERC20(token0).balanceOf(address(this)) > 1;

            // try swap
            bool success = _swap(pool, zeroForOne);

            // if first swap fails, flip zeroForOne and try again
            if (!success) {
                success = _swap(pool, !zeroForOne);

                // if it still fails, record it as a failed pair and report in the return data, don't revert
                if (!success) {
                    failedIndex[failedLength] = index;
                    failedPool[failedLength] = address(pool);
                    failedLength++;
                }
            }

            // records if any swaps were a success
            if (success) {
                didSwap = true;
            }
        }

        if (!didSwap && !force) {
            revert("no swaps");
        }

        // trim length if needed
        if (failedLength != failedIndex.length) {
            assembly ("memory-safe") {
                mstore(failedIndex, failedLength)
                mstore(failedPool, failedLength)
            }
        }

        return (failedIndex, failedPool);
    }

    function findNotUpdated() public view returns (address[] memory pools) {
        uint256 end = clPools.length();
        pools = new address[](end);

        uint256 notUpdatedLength = 0;
        uint256 index;
        uint256 period = block.timestamp / (86400 * 7);
        for (index = 0; index < end; index++) {
            IRamsesV3Pool pool = IRamsesV3Pool(clPools.at(index));
            if (pool.lastPeriod() != period) {
                pools[notUpdatedLength] = address(pool);
                notUpdatedLength++;
            }
        }

        // trim length if needed
        if (notUpdatedLength != pools.length) {
            assembly ("memory-safe") {
                mstore(pools, notUpdatedLength)
            }
        }
    }

    function _swap(IRamsesV3Pool pool, bool zeroForOne) internal returns (bool _success) {
        (uint160 priceLimit,,,,,,) = pool.slot0();
        priceLimit = zeroForOne ? priceLimit - 1 : priceLimit + 1;

        // this part is not needed anymore since swapDust() tries both ways if the first one fails now
        // flip trade direction if needed
        // if (priceLimit <= MIN_SQRT_RATIO) {
        //     priceLimit = priceLimit + 2;
        //     zeroForOne = !zeroForOne;
        // }
        // if (priceLimit >= MAX_SQRT_RATIO) {
        //     priceLimit = priceLimit - 2;
        //     zeroForOne = !zeroForOne;
        // }

        bytes memory _returndata;
        (_success, _returndata) = address(pool).call(
            abi.encodeCall(IRamsesV3PoolActions.swap, (address(this), zeroForOne, 0.01 ether, priceLimit, ""))
        );

        // if (!_success) {
        //     assembly {
        //         returndatacopy(0, 0, returndatasize())
        //         revert(0, returndatasize())
        //     }
        // }
    }

    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata //data
    ) external onlyRunning {
        if (amount0Delta > 0) {
            IERC20(_tempToken0).transfer(msg.sender, uint256(amount0Delta));
        }

        if (amount1Delta > 0) {
            IERC20(_tempToken1).transfer(msg.sender, uint256(amount1Delta));
        }
    }

    function sweep(address _token) external onlyOwner {
        IERC20(_token).transfer(msg.sender, IERC20(_token).balanceOf(address(this)));
    }

    function execute(address _target, bytes calldata _payload) external onlyOwner returns (bytes memory _returndata) {
        bool _success;
        (_success, _returndata) = _target.call(_payload);

        if (!_success) {
            assembly {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }
    }

    function onERC721Received(
        address, // operator
        address, // from
        uint256, // tokenId
        bytes calldata // data
    ) external pure returns (bytes4 retval) {
        return this.onERC721Received.selector;
    }
}
