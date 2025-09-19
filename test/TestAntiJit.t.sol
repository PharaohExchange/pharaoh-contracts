// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {Pharaoh} from "../contracts/Pharaoh.sol";
import {XPhar} from "../contracts/xPhar/XPhar.sol";
import {ClGaugeFactory} from "../contracts/CL/gauge/ClGaugeFactory.sol";
import {GaugeFactory} from "../contracts/factories/GaugeFactory.sol";
import {RewardValidator} from "../contracts/CL/gauge/RewardValidator.sol";
import {GaugeV3} from "../contracts/CL/gauge/GaugeV3.sol";
import {Voter} from "../contracts/Voter.sol";
import {Minter} from "../contracts/Minter.sol";
import {VoteModule} from "../contracts/VoteModule.sol";
import {FeeDistributorFactory} from "../contracts/factories/FeeDistributorFactory.sol";
import {IVoter} from "../contracts/interfaces/IVoter.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {IPairFactory} from "../contracts/interfaces/IPairFactory.sol";
import {IFeeDistributor} from "../contracts/interfaces/IFeeDistributor.sol";
import {IFeeRecipientFactory} from "../contracts/interfaces/IFeeRecipientFactory.sol";
import {TestERC20} from "./TestERC20.sol";
import {AccessHub} from "../contracts/AccessHub.sol";
import {IAccessHub} from "../contracts/interfaces/IAccessHub.sol";
import {IGaugeV3} from "../contracts/CL/gauge/interfaces/IGaugeV3.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {RamsesV3PositionManager} from "../contracts/CL/periphery/RamsesV3PositionManager.sol";
import {IClGaugeFactory} from "../contracts/CL/gauge/interfaces/IClGaugeFactory.sol";
import {NonfungiblePositionManager} from "../contracts/CL/periphery/NonfungiblePositionManager.sol";
import {IRamsesV3PositionManager} from "../contracts/CL/periphery/interfaces/IRamsesV3PositionManager.sol";
import {INonfungiblePositionManager} from "../contracts/CL/periphery/interfaces/INonfungiblePositionManager.sol";
import {IRamsesV3Pool} from "../contracts/CL/core/interfaces/IRamsesV3Pool.sol";

contract TestAntiJit is Test {
    address constant PHAR = 0xEfD81eeC32B9A8222D1842ec3d99c7532C31e348;
    address constant XPHAR = 0xc93B315971A4f260875103F5DA84cB1E30f366Cc;
    address constant P33 = 0xe4eEB461Ad1e4ef8b8EF71a33694CCD84Af051C4;
    address constant ETHEREX_DEPLOYER = 0x676F11a28E5F8A3ebF6Ae1187f05C30b0A95a8b0;
    address constant LEGACY_GAUGE_FACTORY = 0xD766d9dA469C4A7D325b66FFCF33139650C4a200;
    address constant FEE_DISTRIBUTOR_FACTORY = 0xfde48794F3EA7F26Cd2b00f078366455B1e6b7bf;
    address constant FEE_RECIPIENT_FACTORY = 0x75430C78a65bfB7dCdF89a3F0DAa8da36402d6A7;
    address constant PAIR_FACTORY = 0xC0b920f6f1d6122B8187c031554dc8194F644592;
    address constant ROUTER = 0x32dB39c56C171b4c96e974dDeDe8E42498929c54;
    address constant VOTER = 0x942117Ec0458a8AA08669E94B52001Bd43F889C1;
    address constant VOTE_MODULE = 0xedD7cbc9C47547D0b552d5Bc2BE76135f49C15b1;
    address constant MINTER = 0x0b6d3B42861eE8aBFCaaC818033694E758ECC3eb;
    
    address constant ETHEREX_TEAM_MULTISIG = 0xde4B22Eb9F9c2C55e72e330C87663b28e9d388f7;
    address constant SUF_POL_SAFE = 0x007e783be0F271510EF919357466C122Fd539ccE;
    address constant ETHEREX_TIMELOCK = 0xF9A15373c36f50E0DeA03E80a568F03392d89944;
    address constant ACCESS_HUB_PROXY_ADMIN = 0x3950D9b43C77Cf5E165Ee9aa5C59EfdC5A542Dc3;
    address constant VOTER_PROXY_ADMIN = 0xdc78E9400ba73Dad459B6179b06e1E70853D384e;
    address constant TREASURY_HELPER_PROXY_ADMIN = 0xfB26764029284b0873061BB8790271eC7d8F6eDF;
    address constant TREASURY_HELPER = 0x15325A2EC4BF164D47CF48D5D6a9EDdA385636A5;
    address constant ACCESS_HUB = 0x683035188E3670fda1deF2a7Aa5742DEa28Ed5f3;
    
    address constant ETHEREX_V3_FACTORY = 0xAe334f70A7FC44FCC2df9e6A37BC032497Cf80f1;
    address constant FEE_COLLECTOR = 0x532C15d1803F565Ad37b77f5B20D9E3a4254e0F3;
    address constant ETHEREX_V3_POOL_DEPLOYER = 0x80dcA113B33CE4Da3A7AAc15c2e62Fc6D6c7bEC8;
    address constant ETHEREX_V3_GAUGE_FACTORY = 0x499AED38bDafd972E1cd2926D2B9088547DD8Fcb;
    address constant NONFUNGIBLE_POSITION_MANAGER = 0xA04A9F0a961f8fcc4a94bCF53e676B236cBb2F58;
    address constant NONFUNGIBLE_TOKEN_POSITION_DESCRIPTOR = 0xfC65c6308765ebbB0d87df8b6502674B868453C4;
    address constant UNIVERSAL_ROUTER = 0x85974429677c2a701af470B82F3118e74307826e;
    address constant SWAP_ROUTER = 0x8BE024b5c546B5d45CbB23163e1a4dca8fA5052A;
    address constant QUOTER_V2 = 0xE660C95E17884b6C81B01445EFC24556f8ABa037;
    address constant QUOTER_V1 = 0xb593Fa9d853AD89BfCf77c9a22D24936774FE335;
    address constant TICK_LENS = 0x432a5219320d4Ae3ebf33A84ae9944F655e8E2B8;
    address constant UNISWAP_INTERFACE_MULTICALL = 0x1211fb02d3C61fD576E76675ce9CB38230eE5B3E;
    address constant MIXED_ROUTE_QUOTER_V1 = 0x59037f2C0337a5150c0Cd08CB2DF684e043712A6;
    address constant WETH = 0xe5D7C2a44FfDDf6b295A15c148167daaAf5Cf34f;
    address constant RAMSES_V3_POSITION_MANAGER = 0x4E710FEb1B2e784233893af659442e4739272BfB;
    
    address constant REWARD_VALIDATOR = 0xF2643190116ED2a9C3CFbD3C489a60D4A51Bb458;
    address constant REWARD_VALIDATOR_PROXY_ADMIN = 0xAB763440836C39276E28a6cdc68aB6dee1993aBB;
    
    address constant ETH_USDC_POOL = 0x90E8a5b881D211f418d77Ba8978788b62544914B;

    function setUp() public {
        vm.createSelectFork(vm.envString("LINEA_RPC"), 22602000);
        vm.startPrank(ETHEREX_TEAM_MULTISIG);
        
        // Deploy and upgrade GaugeV3 implementation
        GaugeV3 gaugeV3Impl = new GaugeV3();
        IAccessHub(ACCESS_HUB).setClGaugeFactoryImpl(address(gaugeV3Impl));
        
        // Deploy and upgrade RewardValidator implementation
        RewardValidator rewardValidatorImpl = new RewardValidator();
        ProxyAdmin(REWARD_VALIDATOR_PROXY_ADMIN).upgradeAndCall(
            ITransparentUpgradeableProxy(REWARD_VALIDATOR), 
            address(rewardValidatorImpl),
            ""
        );
        
        // Deploy and upgrade Voter implementation
        Voter voterImpl = new Voter();
        ProxyAdmin(VOTER_PROXY_ADMIN).upgradeAndCall(
            ITransparentUpgradeableProxy(VOTER),
            address(voterImpl),
            ""
        );

        vm.stopPrank();
        
        vm.startPrank(IAccessHub(ACCESS_HUB).timelock());
        RamsesV3PositionManager(payable(RAMSES_V3_POSITION_MANAGER)).setVoter(IVoter(VOTER));
        vm.stopPrank();
    }
    
    function _mintTestPosition(address _nfpManager, address _owner) internal returns (uint256 tokenId, uint128 liquidity) {
        IRamsesV3Pool pool = IRamsesV3Pool(ETH_USDC_POOL);
        address token0 = pool.token0();
        address token1 = pool.token1();
        int24 tickSpacing = pool.tickSpacing();
        
        (, int24 currentTick, , , , , ) = pool.slot0();
        
        int24 tickLower = ((currentTick - 1000) / tickSpacing) * tickSpacing;
        int24 tickUpper = ((currentTick + 1000) / tickSpacing) * tickSpacing;
        
        deal(token0, _owner, 1 ether);
        deal(token1, _owner, 3000e6);
        
        vm.startPrank(_owner);
        
        IERC20(token0).approve(_nfpManager, 1 ether);
        IERC20(token1).approve(_nfpManager, 3000e6);
        
        INonfungiblePositionManager.MintParams memory mintParams = INonfungiblePositionManager.MintParams({
            token0: token0,
            token1: token1,
            tickSpacing: tickSpacing,
            tickLower: tickLower,
            tickUpper: tickUpper,
            amount0Desired: 0.1 ether,
            amount1Desired: 3000e6,
            amount0Min: 0,
            amount1Min: 0,
            recipient: _owner,
            deadline: block.timestamp + 1 hours
        });
        
        uint256 amount0;
        uint256 amount1;
        (tokenId, liquidity, amount0, amount1) = 
            INonfungiblePositionManager(_nfpManager).mint(mintParams);
        
        console.log("Test position minted:");
        console.log("  Token ID:", tokenId);
        console.log("  Liquidity:", liquidity);
        console.log("  Amount0 used:", amount0);
        console.log("  Amount1 used:", amount1);
        
        vm.stopPrank();
    }

    function _increaseLiquidity(address _nfpManager, address _owner, uint256 _tokenId) internal {
        IRamsesV3Pool pool = IRamsesV3Pool(ETH_USDC_POOL);
        address token0 = pool.token0();
        address token1 = pool.token1();

        deal(token0, _owner, 1 ether);
        deal(token1, _owner, 3000e6);

        vm.startPrank(_owner);

        IERC20(token0).approve(_nfpManager, 1 ether);
        IERC20(token1).approve(_nfpManager, 3000e6);
        NonfungiblePositionManager(payable(_nfpManager)).increaseLiquidity(INonfungiblePositionManager.IncreaseLiquidityParams({
            tokenId: _tokenId,
            amount0Desired: 1000,
            amount1Desired: 1000,
            amount0Min: 0,
            amount1Min: 0,
            deadline: block.timestamp
        }));

        vm.stopPrank();
    }

    function test_claimRewardsOldNfpManager() public {
        address OWNER = ETHEREX_TEAM_MULTISIG;
        
        (uint256 nfpId, ) = _mintTestPosition(NONFUNGIBLE_POSITION_MANAGER, OWNER);
        
        vm.warp(block.timestamp + 7 days);
        
        vm.startPrank(OWNER);
        
        address gauge = IVoter(VOTER).gaugeForPool(ETH_USDC_POOL);
        uint256 rexBalanceBefore = IERC20(PHAR).balanceOf(OWNER);
        console.log("Rex balance before:", rexBalanceBefore);
        
        address[] memory gauges = new address[](1);
        gauges[0] = gauge;
        
        address[][] memory tokensToClaim = new address[][](1);
        tokensToClaim[0] = new address[](1);
        tokensToClaim[0][0] = PHAR;
        
        uint256[][] memory nfpTokenIds = new uint256[][](1);
        nfpTokenIds[0] = new uint256[](1);
        nfpTokenIds[0][0] = nfpId;

        IVoter(VOTER).claimClGaugeRewards(
            gauges,
            tokensToClaim,
            nfpTokenIds
        );

        uint256 rexBalanceAfter = IERC20(PHAR).balanceOf(OWNER);
        console.log("Rex balance after:", rexBalanceAfter);

        assertGt(rexBalanceAfter, rexBalanceBefore, "No rewards earned (might need emissions to be active)");
        console.log("Rewards earned:", rexBalanceAfter - rexBalanceBefore);
        
        vm.stopPrank();
    }

    function test_blacklistAndClaimRewardsOldNfpManager() public {
        address OWNER = ETHEREX_TEAM_MULTISIG;
        
        (uint256 nfpId, ) = _mintTestPosition(NONFUNGIBLE_POSITION_MANAGER, OWNER);
        
        // Wait for rewards to accumulate
        vm.warp(block.timestamp + 7 days);
        
        address gauge = IVoter(VOTER).gaugeForPool(ETH_USDC_POOL);
        
        // Sync gauge cache to ensure r33 is set
        IGaugeV3(gauge).syncCache();
        
        // Check rewards earned before claiming
        uint256 rewardsEarned = IGaugeV3(gauge).earned(PHAR, nfpId);
        console.log("Rewards earned by position:", rewardsEarned);
        
        uint256 rexBalanceBefore = IERC20(PHAR).balanceOf(OWNER);
        uint256 p33BalanceBefore = IERC20(PHAR).balanceOf(P33);
        console.log("Rex balance before:", rexBalanceBefore);
        console.log("P33 balance before:", p33BalanceBefore);
        
        vm.prank(IAccessHub(ACCESS_HUB).treasury());
        RewardValidator(REWARD_VALIDATOR).addNfpToBlacklist(nfpId, NONFUNGIBLE_POSITION_MANAGER);
        
        vm.prank(OWNER);
        address[] memory tokensToClaim = new address[](1);
        tokensToClaim[0] = PHAR;
        
        NonfungiblePositionManager(payable(NONFUNGIBLE_POSITION_MANAGER)).getReward(nfpId, tokensToClaim);

        uint256 rexBalanceAfter = IERC20(PHAR).balanceOf(OWNER);
        uint256 p33BalanceAfter = IERC20(PHAR).balanceOf(P33);
        console.log("Rex balance after:", rexBalanceAfter);
        console.log("P33 balance after:", p33BalanceAfter);

        assertEq(rexBalanceAfter, rexBalanceBefore, "Owner received rewards");
        assertGt(p33BalanceAfter, p33BalanceBefore, "Rewards should have been sent to P33 due to blacklist");
        console.log("Rewards sent to P33:", p33BalanceAfter - p33BalanceBefore);
    }

    function test_mintAndWithdrawAboveThresholdNewNfpManager() public {
        address OWNER = ETHEREX_TEAM_MULTISIG;
        
        (uint256 tokenId, uint128 liquidity) = _mintTestPosition(RAMSES_V3_POSITION_MANAGER, OWNER);
        
        console.log("Position minted on RamsesV3PositionManager:");
        console.log("  Token ID:", tokenId);
        console.log("  Liquidity:", liquidity);
        
        uint256 rexBalanceBefore = IERC20(PHAR).balanceOf(OWNER);
        uint256 p33BalanceBefore = IERC20(PHAR).balanceOf(P33);
        console.log("\nREX balance before:", rexBalanceBefore);
        console.log("P33 balance before:", p33BalanceBefore);
        
        vm.warp(block.timestamp + 7 days);
        
        address gauge = IVoter(VOTER).gaugeForPool(ETH_USDC_POOL);
        console.log("Gauge for pool:", gauge);
        
        uint256 rexBalanceAfter;
        uint256 p33BalanceAfter;
        uint256 snapshotId = vm.snapshot();
        // INCREASE_LIQUIDITY
        {
            console.log("### INCREASE_LIQUIDITY ###");
            _increaseLiquidity(RAMSES_V3_POSITION_MANAGER, OWNER, tokenId);
            
            rexBalanceAfter = IERC20(PHAR).balanceOf(OWNER);
            p33BalanceAfter = IERC20(PHAR).balanceOf(P33);
            console.log("PHAR balance after claim:", rexBalanceAfter);
            console.log("P33 balance after claim:", p33BalanceAfter);
            assertEq(p33BalanceAfter, p33BalanceBefore, "Rewards sent to blacklist");
            assertGt(rexBalanceAfter, rexBalanceBefore, "No rewards earned (might need emissions to be active)");
            console.log("Rewards earned by owner:", rexBalanceAfter - rexBalanceBefore);
            vm.revertTo(snapshotId);
        }

        vm.startPrank(OWNER);
        // DECREASE_LIQUIDITY
        {
            console.log("### DECREASE_LIQUIDITY ###");            
            NonfungiblePositionManager(payable(RAMSES_V3_POSITION_MANAGER)).decreaseLiquidity(INonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId: tokenId,
                liquidity: 1000,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp
            }));

            rexBalanceAfter = IERC20(PHAR).balanceOf(OWNER);
            p33BalanceAfter = IERC20(PHAR).balanceOf(P33);
            console.log("PHAR balance after claim:", rexBalanceAfter);
            console.log("P33 balance after claim:", p33BalanceAfter);
            assertEq(p33BalanceAfter, p33BalanceBefore, "Rewards sent to blacklist");
            assertGt(rexBalanceAfter, rexBalanceBefore, "No rewards earned (might need emissions to be active)");
            console.log("Rewards earned by owner:", rexBalanceAfter - rexBalanceBefore);
            vm.revertTo(snapshotId);
        }

        // CLAIM_REWARDS
        {
            console.log("### CLAIM_REWARDS ###");
            address[] memory rewardTokens = new address[](1);
            rewardTokens[0] = PHAR;

            console.log("\nAttempting to claim rewards for tokenId:", tokenId);
            IRamsesV3PositionManager(RAMSES_V3_POSITION_MANAGER).getReward(tokenId, rewardTokens);

            rexBalanceAfter = IERC20(PHAR).balanceOf(OWNER);
            p33BalanceAfter = IERC20(PHAR).balanceOf(P33);
            console.log("PHAR balance after claim:", rexBalanceAfter);
            console.log("P33 balance after claim:", p33BalanceAfter);
            assertEq(p33BalanceAfter, p33BalanceBefore, "Rewards sent to blacklist");
            assertGt(rexBalanceAfter, rexBalanceBefore, "No rewards earned (might need emissions to be active)");
            console.log("Rewards earned by owner:", rexBalanceAfter - rexBalanceBefore);
        }
        vm.stopPrank();
    }


    function test_mintAndWithdrawBelowThresholdNewNfpManager() public {
        address OWNER = ETHEREX_TEAM_MULTISIG;
    
        (uint256 nfpId, ) = _mintTestPosition(RAMSES_V3_POSITION_MANAGER, OWNER);
        
        // Blacklist the position to test rewards going to P33
        vm.prank(IAccessHub(ACCESS_HUB).treasury());
        RewardValidator(REWARD_VALIDATOR).addNfpToBlacklist(nfpId, RAMSES_V3_POSITION_MANAGER);
        
        // Wait for rewards to accumulate from existing pool emissions
        vm.warp(block.timestamp + 7 days);
        
        // Check rewards earned using the correct overload that accepts nfpManager address
        IGaugeV3 gauge = IGaugeV3(IVoter(VOTER).gaugeForPool(ETH_USDC_POOL));
        uint256 rewardsEarned = gauge.earned(PHAR, RAMSES_V3_POSITION_MANAGER, nfpId);
        console.log("Rewards earned by position after 7 days:", rewardsEarned);

        uint256 rexBalanceBefore = IERC20(PHAR).balanceOf(OWNER);
        uint256 p33BalanceBefore = IERC20(PHAR).balanceOf(P33);
        console.log("PHAR balance before:", rexBalanceBefore);
        console.log("P33 balance before:", p33BalanceBefore);

        uint256 rexBalanceAfter;
        uint256 p33BalanceAfter;
        uint256 snapshotId = vm.snapshot();
        // INCREASE_LIQUIDITY
        {
            console.log("### INCREASE_LIQUIDITY ###");
            _increaseLiquidity(RAMSES_V3_POSITION_MANAGER, OWNER, nfpId);

            rexBalanceAfter = IERC20(PHAR).balanceOf(OWNER);
            p33BalanceAfter = IERC20(PHAR).balanceOf(P33);
            console.log("PHAR balance after:", rexBalanceAfter);
            console.log("P33 balance after:", p33BalanceAfter);
            
            assertEq(rexBalanceAfter, rexBalanceBefore, "Owner received rewards when blacklisted");
            assertGt(p33BalanceAfter, p33BalanceBefore, "Rewards not sent to P33");
            console.log("Rewards sent to P33:", p33BalanceAfter - p33BalanceBefore);
            vm.revertTo(snapshotId);
        }

        // DECREASE_LIQUIDITY
        {
            console.log("### DECREASE_LIQUIDITY ###");

            vm.prank(OWNER);
            NonfungiblePositionManager(payable(RAMSES_V3_POSITION_MANAGER)).decreaseLiquidity(INonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId: nfpId,
                liquidity: 1000,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp
            }));

            rexBalanceAfter = IERC20(PHAR).balanceOf(OWNER);
            p33BalanceAfter = IERC20(PHAR).balanceOf(P33);
            console.log("PHAR balance after:", rexBalanceAfter);
            console.log("P33 balance after:", p33BalanceAfter);

            assertEq(rexBalanceAfter, rexBalanceBefore, "Owner received rewards when blacklisted");
            assertGt(p33BalanceAfter, p33BalanceBefore, "Rewards not sent to P33");
            console.log("Rewards sent to P33:", p33BalanceAfter - p33BalanceBefore);
            vm.revertTo(snapshotId);
        }

        // CLAIM_REWARDS
        {
            console.log("### CLAIM_REWARDS ###");
            address[] memory rewardTokens = new address[](1);
            rewardTokens[0] = PHAR;
            
            vm.prank(OWNER);
            IRamsesV3PositionManager(RAMSES_V3_POSITION_MANAGER).getReward(nfpId, rewardTokens);

            rexBalanceAfter = IERC20(PHAR).balanceOf(OWNER);
            p33BalanceAfter = IERC20(PHAR).balanceOf(P33);
            console.log("PHAR balance after:", rexBalanceAfter);
            console.log("P33 balance after:", p33BalanceAfter);

            assertEq(rexBalanceAfter, rexBalanceBefore, "Owner received rewards when blacklisted");
            assertGt(p33BalanceAfter, p33BalanceBefore, "Rewards not sent to P33");
            console.log("Rewards sent to P33:", p33BalanceAfter - p33BalanceBefore);
            vm.revertTo(snapshotId);
        }
    }
}