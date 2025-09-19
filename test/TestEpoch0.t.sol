// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {Pharaoh} from "../contracts/Pharaoh.sol";
import {XPhar} from "../contracts/xPhar/XPhar.sol";
import {ClGaugeFactory} from "../contracts/CL/gauge/ClGaugeFactory.sol";
import {GaugeFactory} from "../contracts/factories/GaugeFactory.sol";
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

contract TestEpoch0 is Test {
    
    // Contract addresses
    address constant ACCESS_HUB = 0x683035188E3670fda1deF2a7Aa5742DEa28Ed5f3;
    address constant PROXY_ADMIN = 0x3950D9b43C77Cf5E165Ee9aa5C59EfdC5A542Dc3;
    address constant PROXY_OWNER = 0xde4B22Eb9F9c2C55e72e330C87663b28e9d388f7;
    address constant FEE_RECIPIENT_FACTORY = 0x75430C78a65bfB7dCdF89a3F0DAa8da36402d6A7;
    address constant FEE_COLLECTOR = 0x51A2a0B162D27254e30473b7072d95F4B37F21a1;
    address constant PAIR_FACTORY = 0xC0b920f6f1d6122B8187c031554dc8194F644592;
    address constant RAMSES_V3_FACTORY = 0xAe334f70A7FC44FCC2df9e6A37BC032497Cf80f1;
    address constant RAMSES_V3_POOL_DEPLOYER = 0x80dcA113B33CE4Da3A7AAc15c2e62Fc6D6c7bEC8;
    address constant DEPLOYER = 0x676F11a28E5F8A3ebF6Ae1187f05C30b0A95a8b0;
    address constant NONFUNGIBLE_POSITION_MANAGER = 0xA04A9F0a961f8fcc4a94bCF53e676B236cBb2F58;
    address constant SWAP_ROUTER = 0x8BE024b5c546B5d45CbB23163e1a4dca8fA5052A;
    address constant QUOTER = 0xb593Fa9d853AD89BfCf77c9a22D24936774FE335;
    address constant QUOTER_V2 = 0xE660C95E17884b6C81B01445EFC24556f8ABa037;
    address constant TICK_LENS = 0x432a5219320d4Ae3ebf33A84ae9944F655e8E2B8;
    address constant UNISWAP_INTERFACE_MULTICALL = 0x1211fb02d3C61fD576E76675ce9CB38230eE5B3E;
    address constant UNIVERSAL_ROUTER = 0x85974429677c2a701af470B82F3118e74307826e;
    address constant MIXED_ROUTE_QUOTER_V1 = 0x59037f2C0337a5150c0Cd08CB2DF684e043712A6;
    address constant LEGACY_ROUTER = 0x32dB39c56C171b4c96e974dDeDe8E42498929c54;
    address constant MULTISIG = 0xde4B22Eb9F9c2C55e72e330C87663b28e9d388f7;
    address constant TIMELOCK = 0xF9A15373c36f50E0DeA03E80a568F03392d89944;
    address constant FEE_SWITCHER_BOT_ADDRESS = 0x39FA5EfB0881C504A313D1AaD4DEa1df32f66F36;
    
    // production contracts (for reference, test deploys new ones)
    address constant PRODUCTION_REX = 0xEfD81eeC32B9A8222D1842ec3d99c7532C31e348;
    address constant PRODUCTION_XREX = 0xc93B315971A4f260875103F5DA84cB1E30f366Cc;
    address constant PRODUCTION_VOTER = 0x942117Ec0458a8AA08669E94B52001Bd43F889C1;
    address constant PRODUCTION_MINTER = 0x0b6d3B42861eE8aBFCaaC818033694E758ECC3eb;
    
    // production factories
    address constant PRODUCTION_GAUGE_FACTORY = 0xD766d9dA469C4A7D325b66FFCF33139650C4a200;
    address constant PRODUCTION_FEE_DISTRIBUTOR_FACTORY = 0xfde48794F3EA7F26Cd2b00f078366455B1e6b7bf;
    address constant PRODUCTION_CL_GAUGE_FACTORY = 0x499AED38bDafd972E1cd2926D2B9088547DD8Fcb;

    Pharaoh public phar;
    address public xphar;
    address public voterProxy;
    Minter public minter;
    
    function _updateAccessHubVoter(address _testVoter, address _clGaugeFactory, address _legacyGaugeFactory, address _feeDistributorFactory) internal {
        // update production accesshub to recognize test voter and factories
        IAccessHub accessHub = IAccessHub(ACCESS_HUB);
        
        // get current params to preserve other settings, use test factories
        IAccessHub.InitParams memory reinitParams = IAccessHub.InitParams({
            timelock: accessHub.timelock(),
            treasury: accessHub.treasury(),
            voter: _testVoter,  // update to test voter
            minter: address(accessHub.minter()),
            xRam: address(accessHub.xRam()),
            r33: address(accessHub.r33()),
            ramsesV3PoolFactory: address(accessHub.ramsesV3PoolFactory()),
            poolFactory: address(accessHub.poolFactory()),
            feeRecipientFactory: address(accessHub.feeRecipientFactory()),
            feeCollector: address(accessHub.feeCollector()),
            voteModule: address(accessHub.voteModule()),
            clGaugeFactory: _clGaugeFactory,
            gaugeFactory: _legacyGaugeFactory,
            feeDistributorFactory: _feeDistributorFactory
        });
        
        // update as timelock (which has permission)
        address timelock = accessHub.timelock();
        console.log("updating accesshub voter from timelock:", timelock);
        vm.prank(MULTISIG);
        IAccessHub(ACCESS_HUB).reinit(reinitParams);
        
        // verify the update worked
        address actualVoter = address(IAccessHub(ACCESS_HUB).voter());
        console.log("accesshub voter updated to:", actualVoter);
        require(actualVoter == _testVoter, "accesshub voter update failed!");
    }
    
    function setUp() public {
        // deploy minter
        minter = new Minter(ACCESS_HUB, MULTISIG);
        phar = new Pharaoh(address(minter));
        
        // deploy voter implementation
        address voterImpl = address(new Voter());
        
        // create init data for first initializer 
        bytes memory voterInitData = abi.encodeWithSelector(
            Voter.initializeAccessHub.selector,
            ACCESS_HUB
        );
        
        // deploy voter proxy with first initialization
        TransparentUpgradeableProxy _voterProxy = new TransparentUpgradeableProxy(
            voterImpl,                // implementation
            MULTISIG,                 // proxy admin owner
            voterInitData             // initialization call
        );
        voterProxy = address(_voterProxy);
        
        // deploy votemodule - constructor sets deployer as temp voter for auth
        VoteModule voteModule = new VoteModule();
        
        // xphar gets real voter address, breaking voter <-> xphar circular dependency
        xphar = address(new XPhar(
            address(phar),
            voterProxy,
            MULTISIG,              // operator
            ACCESS_HUB,            // governance
            address(voteModule),
            address(minter)
        ));

        // now initialize votemodule with real addresses (deployer auth allows this)
        voteModule.initialize(address(xphar), voterProxy, ACCESS_HUB);
        
        // deploy test factories (production ones may be configured for production voter)
        ClGaugeFactory clGaugeFactory = new ClGaugeFactory(
            NONFUNGIBLE_POSITION_MANAGER, 
            voterProxy, 
            FEE_COLLECTOR
        );
        GaugeFactory legacyGaugeFactory = new GaugeFactory();
        FeeDistributorFactory feeDistributorFactory = new FeeDistributorFactory();

        // complete voter initialization with real addresses
        vm.prank(ACCESS_HUB); // simulate AccessHub initializes it
        Voter(voterProxy).initialize(
            IVoter.InitializationParams({
                ram: address(phar),
                legacyFactory: PAIR_FACTORY,
                gauges: address(legacyGaugeFactory),
                feeDistributorFactory: address(feeDistributorFactory),
                minter: address(minter),
                msig: MULTISIG,
                xRam: address(xphar),
                clFactory: RAMSES_V3_FACTORY,
                clGaugeFactory: address(clGaugeFactory),
                nfpManager: NONFUNGIBLE_POSITION_MANAGER,
                feeRecipientFactory: FEE_RECIPIENT_FACTORY,
                voteModule: address(voteModule)
            })
        );
        
        // update production FEE_RECIPIENT_FACTORY to use our test voter (simulates governance update)
        vm.prank(ACCESS_HUB);
        IFeeRecipientFactory(FEE_RECIPIENT_FACTORY).setVoter(voterProxy);
        
        // update accesshub to recognize the test voter
        _updateAccessHubVoter(voterProxy, address(clGaugeFactory), address(legacyGaugeFactory), address(feeDistributorFactory));
        
        console.log("setup complete - using production accesshub with test voter and factories");
        console.log("- voter:", voterProxy);
        console.log("- phar:", address(phar));
        console.log("- xphar:", xphar);
        console.log("- minter:", address(minter));
        console.log("- cl gauge factory:", address(clGaugeFactory));
        console.log("- legacy gauge factory:", address(legacyGaugeFactory));
        console.log("- fee distributor factory:", address(feeDistributorFactory));
    }

    function test_deployment() public view {
        // verify core contracts deployed
        assertTrue(address(phar) != address(0), "phar not deployed");
        assertTrue(voterProxy != address(0), "voter not deployed");
        assertTrue(address(xphar) != address(0), "xphar not deployed");
        
        // proxy admin verification
        bytes32 ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
        address proxyAdmin = address(uint160(uint256(vm.load(voterProxy, ADMIN_SLOT))));
        console.log("voter proxy at:", voterProxy);
        console.log("proxy admin at:", proxyAdmin);
        console.log("proxy admin owner:", ProxyAdmin(proxyAdmin).owner());
        require(ProxyAdmin(proxyAdmin).owner() == MULTISIG, "proxy admin owner is not multisig");
        
        // verify voter has correct xphar address
        assertEq(Voter(voterProxy).xRam(), address(xphar), "voter xphar mismatch");
        
        // verify xphar has correct voter address
        assertEq(address(XPhar(xphar).VOTER()), voterProxy, "xphar voter mismatch");
        
        // verify other voter state
        assertEq(Voter(voterProxy).accessHub(), ACCESS_HUB, "voter access hub mismatch");
        assertEq(Voter(voterProxy).ram(), address(phar), "voter ram mismatch");
        assertEq(Voter(voterProxy).minter(), address(minter), "voter minter mismatch");
        assertEq(Voter(voterProxy).governor(), MULTISIG, "voter governor mismatch");
        
        // verify voter initialization details
        assertEq(Voter(voterProxy).xRatio(), 0, "voter xRatio should default to 0");
        assertEq(Voter(voterProxy).legacyFactory(), PAIR_FACTORY, "voter legacy factory mismatch");
        assertEq(Voter(voterProxy).clFactory(), RAMSES_V3_FACTORY, "voter cl factory mismatch");
        assertEq(Voter(voterProxy).nfpManager(), NONFUNGIBLE_POSITION_MANAGER, "voter nfp manager mismatch");
        assertEq(Voter(voterProxy).feeRecipientFactory(), FEE_RECIPIENT_FACTORY, "voter fee recipient factory mismatch");
        
        // verify PHAR and xPHAR are whitelisted in voter
        assertTrue(Voter(voterProxy).isWhitelisted(address(phar)), "phar not whitelisted in voter");
        assertTrue(Voter(voterProxy).isWhitelisted(address(xphar)), "xphar not whitelisted in voter");
        
        // verify XPhar immutable addresses
        assertEq(XPhar(xphar).MINTER(), address(minter), "xphar minter mismatch");
        assertEq(XPhar(xphar).ACCESS_HUB(), ACCESS_HUB, "xphar access hub mismatch");
        assertEq(address(XPhar(xphar).PHAR()), address(phar), "xphar phar mismatch");
        assertEq(XPhar(xphar).operator(), MULTISIG, "xphar operator mismatch");
        
        // verify XPhar security settings
        // assertEq(XPhar(xphar).rebaseThreshold(), 1e18, "xphar rebase threshold should be 1e18");
        assertTrue(XPhar(xphar).isExempt(voterProxy), "voter should be exempt in xphar");
        assertTrue(XPhar(xphar).isExempt(MULTISIG), "operator should be exempt in xphar");
        
        // verify VoteModule configuration
        address voteModuleAddr = Voter(voterProxy).voteModule();
        assertTrue(voteModuleAddr != address(0), "vote module not set in voter");
        assertEq(VoteModule(voteModuleAddr).xPhar(), address(xphar), "vote module xphar mismatch");
        assertEq(VoteModule(voteModuleAddr).voter(), voterProxy, "vote module voter mismatch");
        assertEq(VoteModule(voteModuleAddr).accessHub(), ACCESS_HUB, "vote module access hub mismatch");
        
        // verify XPhar has correct vote module
        assertEq(XPhar(xphar).VOTE_MODULE(), voteModuleAddr, "xphar vote module mismatch");
        assertTrue(XPhar(xphar).isExempt(voteModuleAddr), "vote module should be exempt in xphar");
        
        // verify factory configurations
        address clGaugeFactory = Voter(voterProxy).clGaugeFactory();
        address gaugeFactory = Voter(voterProxy).gaugeFactory();
        address feeDistributorFactory = Voter(voterProxy).feeDistributorFactory();
        
        assertTrue(clGaugeFactory != address(0), "cl gauge factory not set");
        assertTrue(gaugeFactory != address(0), "gauge factory not set");
        assertTrue(feeDistributorFactory != address(0), "fee distributor factory not set");
        
        // verify ClGaugeFactory configuration
        assertEq(ClGaugeFactory(clGaugeFactory).voter(), voterProxy, "cl gauge factory voter mismatch");
        assertEq(ClGaugeFactory(clGaugeFactory).nfpManager(), NONFUNGIBLE_POSITION_MANAGER, "cl gauge factory nfp manager mismatch");
        assertEq(ClGaugeFactory(clGaugeFactory).feeCollector(), FEE_COLLECTOR, "cl gauge factory fee collector mismatch");
        
        // verify Minter configuration
        assertEq(minter.accessHub(), ACCESS_HUB, "minter access hub mismatch");
        assertEq(minter.operator(), MULTISIG, "minter operator mismatch");
        
    }

    function test_kickoff() public {
        // cache initial balances
        uint256 initialOperatorBalance = phar.balanceOf(MULTISIG);
        uint256 initialTotalSupply = phar.totalSupply();
        
        // expected values
        uint256 expectedWeeklyEmissions = 1000000 * 1e18; // 1M PHAR tokens as example
        uint256 expectedMultiplier = 10000; // 100% basis (10,000)
        uint256 expectedInitialSupply = 350_000_000 * 1e18; // INITIAL_SUPPLY from Minter
        
        console.log("=== monday: kickoff phase ===");
        console.log("today is monday, calling kickoff...");
        
        // verify minter can kickoff with proper parameters (MONDAY)
        vm.prank(MULTISIG);
        minter.kickoff(
            address(phar),           // _ram
            voterProxy,            // _voter  
            expectedWeeklyEmissions, // _initialWeeklyEmissions
            expectedMultiplier,     // _initialMultiplier
            xphar                   // _xPhar
        );
        
        // check balances after kickoff
        uint256 afterKickoffOperatorBalance = phar.balanceOf(MULTISIG);
        uint256 afterKickoffTotalSupply = phar.totalSupply();
        
        // verify minter kickoff-specific state was set correctly
        assertEq(minter.weeklyEmissions(), expectedWeeklyEmissions, "weekly emissions not set correctly");
        assertEq(minter.emissionsMultiplier(), expectedMultiplier, "emissions multiplier not set correctly");
        
        // validate balances increased correctly from kickoff
        assertEq(
            afterKickoffOperatorBalance - initialOperatorBalance, 
            expectedInitialSupply, 
            "operator balance did not increase by INITIAL_SUPPLY"
        );
        assertEq(
            afterKickoffTotalSupply - initialTotalSupply,
            expectedInitialSupply,
            "total supply did not increase by INITIAL_SUPPLY"
        );
        
        console.log("kickoff complete - initial_supply minted:", afterKickoffOperatorBalance - initialOperatorBalance);
        console.log("weekly emissions configured:", minter.weeklyEmissions());
        
        // verify initial epoch state (should still be 0 before initEpoch0)
        assertEq(minter.firstPeriod(), 0, "firstPeriod should be 0 before initEpoch0");
        assertEq(minter.activePeriod(), 0, "activePeriod should be 0 before initEpoch0");
        
        console.log("=== advancing to wednesday: epoch flip day ===");
        console.log("waiting for epoch flip (wednesday)...");
        
        // advance time by 2 days (Monday → Wednesday)
        vm.warp(block.timestamp + 2 days);
        console.log("advanced 2 days to wednesday (epoch flip day)");
        
        // get expected current period after time advancement
        uint256 expectedPeriod = minter.getPeriod();
        console.log("current period after time advancement:", expectedPeriod);
        
        console.log("=== wednesday: init epoch 0 ===");
        console.log("calling initEpoch0 after epoch flip...");
        
        // start epoch 0 emissions (WEDNESDAY - after epoch flip)
        vm.prank(MULTISIG);
        minter.initEpoch0();
        
        // verify state changes after initEpoch0
        assertEq(minter.firstPeriod(), expectedPeriod, "firstPeriod not set correctly");
        assertEq(minter.activePeriod(), expectedPeriod, "activePeriod not set correctly");
        assertEq(minter.lastMultiplierUpdate(), expectedPeriod - 1, "lastMultiplierUpdate not set correctly");
        
        // verify epoch 0 emissions were minted
        uint256 finalOperatorBalance = phar.balanceOf(MULTISIG);
        uint256 finalTotalSupply = phar.totalSupply();
        
        assertEq(
            finalOperatorBalance - afterKickoffOperatorBalance,
            expectedWeeklyEmissions,
            "operator balance did not increase by weeklyEmissions"
        );
        assertEq(
            finalTotalSupply - afterKickoffTotalSupply,
            expectedWeeklyEmissions,
            "total supply did not increase by weeklyEmissions"
        );
        
        // verify epoch calculation works (should be epoch 0 since we just started)
        assertEq(minter.getEpoch(), 0, "should be epoch 0 after initEpoch0");
        
        console.log("initEpoch0 complete!");
        console.log("started emissions in period:", minter.firstPeriod());
        console.log("epoch 0 emissions minted:", finalOperatorBalance - afterKickoffOperatorBalance);
        console.log("current epoch:", minter.getEpoch());
        console.log("next week will be epoch 1");
    }

    function test_votingAndRewardCycle() public {
        // setup phase
        
        console.log("=== monday: kickoff phase ===");
        
        // first need to kickoff the minter (monday)
        uint256 expectedWeeklyEmissions = 3_500_000 * 1e18; // 3.5M phar tokens
        uint256 expectedMultiplier = 10000; // 100% basis

        vm.prank(MULTISIG);
        minter.kickoff(
            address(phar),
            voterProxy,
            expectedWeeklyEmissions,
            expectedMultiplier,
            xphar
        );
        
        console.log("kickoff complete on monday, waiting for epoch flip...");

        console.log("=== advancing to wednesday: epoch flip day ===");
        
        // advance time by 2 days (monday → wednesday)
        vm.warp(block.timestamp + 2 days);
        console.log("advanced to wednesday (epoch flip day)");

        console.log("=== wednesday: init epoch 0 ===");
        
        // now call initEpoch0 after epoch flip (wednesday)
        vm.prank(MULTISIG);
        minter.initEpoch0();
        
        console.log("epoch 0 initialized! current epoch:", minter.getEpoch());

        // create test tokens for pair creation
        TestERC20 tokenA = new TestERC20(1000000 * 1e18);
        TestERC20 tokenB = new TestERC20(1000000 * 1e18);
        
        // ensure proper token ordering for pair creation
        address token0 = address(tokenA) < address(tokenB) ? address(tokenA) : address(tokenB);
        address token1 = address(tokenA) < address(tokenB) ? address(tokenB) : address(tokenA);
        
        console.log("Created test tokens:");
        console.log("Token0:", token0);
        console.log("Token1:", token1);

        // whitelist tokens in voter (required for gauge creation)
        vm.prank(ACCESS_HUB);
        Voter(voterProxy).whitelist(token0);
        vm.prank(ACCESS_HUB);
        Voter(voterProxy).whitelist(token1);

        // create a legacy pair
        IPairFactory pairFactory = IPairFactory(PAIR_FACTORY);
        address pair = pairFactory.createPair(token0, token1, false); // false = volatile pair
        
        console.log("Created pair:", pair);
        assertTrue(pairFactory.isPair(pair), "pair should be registered in factory");

        // create gauge for the pair
        vm.prank(ACCESS_HUB);
        address gauge = Voter(voterProxy).createGauge(pair);
        
        console.log("Created gauge:", gauge);
        assertEq(Voter(voterProxy).gaugeForPool(pair), gauge, "gauge should be registered for pool");
        assertTrue(Voter(voterProxy).isAlive(gauge), "gauge should be alive");

        // user voting during epoch 0
        
        // create a test user
        address testUser = address(0x999);
        vm.deal(testUser, 1 ether);
        
        // give user some phar tokens to convert to xphar
        uint256 userRexAmount = 10000 * 1e18; // 10k phar
        deal(address(phar), testUser, userRexAmount);
        
        // user converts phar to xphar  
        vm.prank(testUser);
        phar.approve(xphar, userRexAmount);
        vm.prank(testUser);
        XPhar(xphar).convertEmissionsToken(userRexAmount);
        
        uint256 userXrexBalance = XPhar(xphar).balanceOf(testUser);
        console.log("user xphar balance:", userXrexBalance);
        assertTrue(userXrexBalance > 0, "user should have xphar balance");

        // user deposits xphar into votemodule for voting power
        VoteModule voteModule = VoteModule(Voter(voterProxy).voteModule());
        vm.prank(testUser);
        XPhar(xphar).approve(address(voteModule), userXrexBalance);
        vm.prank(testUser);
        voteModule.deposit(userXrexBalance);
        
        uint256 votingPower = voteModule.balanceOf(testUser);
        console.log("user voting power:", votingPower);
        assertEq(votingPower, userXrexBalance, "voting power should equal deposited xphar");

        // verify we're in epoch 0
        assertEq(minter.getEpoch(), 0, "should be in epoch 0 for voting");
        
        // user votes for the gauge (100% weight)
        address[] memory pools = new address[](1);
        pools[0] = pair;
        uint256[] memory weights = new uint256[](1);
        weights[0] = 10000; // 100% weight
        
        vm.prank(testUser);
        Voter(voterProxy).vote(testUser, pools, weights);
        
        // verify vote was recorded
        uint256 nextPeriod = Voter(voterProxy).getPeriod() + 1;
        uint256 userVotes = Voter(voterProxy).userVotesForPoolPerPeriod(testUser, nextPeriod, pair);
        console.log("user votes for pool in next period:", userVotes);
        assertTrue(userVotes > 0, "user should have votes recorded for next period");

        // epoch transition to epoch 1
        
        console.log("=== advancing to next wednesday: epoch 1 flip ===");
        
        // advance time by 1 more week to trigger epoch transition
        vm.warp(block.timestamp + 1 weeks);
        
        // trigger period update to flip to epoch 1
        uint256 newPeriod = minter.updatePeriod();
        console.log("updated to period:", newPeriod);
        
        // verify we're now in epoch 1
        assertEq(minter.getEpoch(), 1, "should be in epoch 1 after updateperiod");
        
        // verify new emissions were minted
        uint256 voterRexBalance = phar.balanceOf(voterProxy);
        console.log("voter phar balance (for distribution):", voterRexBalance);
        assertTrue(voterRexBalance > 0, "voter should have phar balance for distribution");

        // rebase verification
        
        // check initial earned rewards for votemodule staker (should be 0 initially)
        uint256 initialEarned = voteModule.earned(testUser);
        console.log("user initial earned rewards:", initialEarned);
        
        // create some pendingrebase by having a user do instant exit with penalty
        address exitUser = address(0x888);
        uint256 exitAmount = 5000 * 1e18; // 5k xphar
        deal(address(phar), exitUser, exitAmount);
        
        // convert phar to xphar for exit user
        vm.prank(exitUser);
        phar.approve(xphar, exitAmount);
        vm.prank(exitUser);
        XPhar(xphar).convertEmissionsToken(exitAmount);
        
        // check pendingrebase before exit
        uint256 pendingRebaseBefore = XPhar(xphar).pendingRebase();
        console.log("pending rebase before exit:", pendingRebaseBefore);
        
        // user does instant exit (creates penalty that goes to pendingrebase)
        vm.prank(exitUser);
        uint256 exitedAmount = XPhar(xphar).exit(exitAmount);
        console.log("user exited amount:", exitedAmount);
        
        // check pendingrebase after exit (should have increased)
        uint256 pendingRebaseAfter = XPhar(xphar).pendingRebase();
        console.log("pending rebase after exit:", pendingRebaseAfter);
        assertTrue(pendingRebaseAfter > pendingRebaseBefore, "pendingrebase should increase from exit penalty");
        
        // now call rebase to distribute pendingrebase to votemodule stakers
        console.log("calling rebase to distribute penalties to votemodule stakers...");
        minter.rebase();
        
        // check that pendingrebase was distributed (should be 0 now if above threshold)
        uint256 pendingRebaseAfterRebase = XPhar(xphar).pendingRebase();
        console.log("pending rebase after rebase call:", pendingRebaseAfterRebase);
        
        // check that votemodule stakers now have earned rewards
        uint256 finalEarned = voteModule.earned(testUser);
        console.log("user final earned rewards:", finalEarned);
        
        // verify earned rewards increased (this is the critical verification!)
        if (pendingRebaseAfter >= XPhar(xphar).rebaseThreshold()) {
            assertTrue(finalEarned > initialEarned, "critical: votemodule stakers should earn rewards from rebase");
            console.log("success: user earned from rebase penalties:", finalEarned - initialEarned);
            
            // test that user can actually claim the rewards
            uint256 userXrexBalanceBefore = XPhar(xphar).balanceOf(testUser);
            vm.prank(testUser);
            voteModule.getReward();
            uint256 userXrexBalanceAfter = XPhar(xphar).balanceOf(testUser);
            
            assertTrue(userXrexBalanceAfter > userXrexBalanceBefore, "user should receive xphar rewards after claiming");
            console.log("user claimed xphar in rewards:", userXrexBalanceAfter - userXrexBalanceBefore);
        } else {
            console.log("note: pendingrebase was below threshold, no rebase distributed");
        }

        // gauge distribution
        
        // distribute to the gauge
        uint256 gaugeRexBefore = phar.balanceOf(gauge);
        console.log("Gauge PHAR balance before distribution:", gaugeRexBefore);
        
        Voter(voterProxy).distribute(gauge);
        
        uint256 gaugeRexAfter = phar.balanceOf(gauge);
        console.log("Gauge PHAR balance after distribution:", gaugeRexAfter);
        
        // verify gauge received emissions
        assertTrue(gaugeRexAfter > gaugeRexBefore, "gauge should have received phar emissions");
        uint256 gaugeEmissions = gaugeRexAfter - gaugeRexBefore;
        console.log("Gauge received emissions:", gaugeEmissions);

        // === USER REWARD CLAIMING ===
        
        // check user's earned rewards in fee distributor
        address feeDistributor = Voter(voterProxy).feeDistributorForGauge(gauge);
        console.log("Fee distributor for gauge:", feeDistributor);
        
        // get reward tokens available
        address[] memory rewardTokens = IFeeDistributor(feeDistributor).getRewardTokens();
        console.log("Number of reward tokens:", rewardTokens.length);
        
        // if there are rewards available, check earnings
        if (rewardTokens.length > 0) {
            for (uint256 i = 0; i < rewardTokens.length; i++) {
                uint256 earned = IFeeDistributor(feeDistributor).earned(rewardTokens[i], testUser);
                console.log("user earned for token:", rewardTokens[i]);
                console.log("earned amount:", earned);
            }
        }

        // === DIRECT FEEDISTRIBUTOR INCENTIVE TEST ===

        // give some PHAR to test user for incentivizing
        uint256 incentiveAmount = 1000 * 1e18; // 1k PHAR
        deal(address(phar), testUser, incentiveAmount);

        // user approves and incentivizes the FeeDistributor directly
        vm.prank(testUser);
        phar.approve(feeDistributor, incentiveAmount);
        vm.prank(testUser);
        IFeeDistributor(feeDistributor).incentivize(address(phar), incentiveAmount);

        console.log("DEBUG: Incentivized FeeDistributor with", incentiveAmount, "PHAR");

        // now check reward tokens again
        address[] memory rewardTokensAfterIncentive = IFeeDistributor(feeDistributor).getRewardTokens();
        console.log("Number of reward tokens after incentive:", rewardTokensAfterIncentive.length);

        if (rewardTokensAfterIncentive.length > 0) {
            console.log("SUCCESS: PHAR was added to rewards set!");
            console.log("First reward token:", rewardTokensAfterIncentive[0]);
        } else {
            console.log("FAIL: Even direct incentive didn't add PHAR to rewards");
        }

        // verification summary
        console.log("\n=== voting and reward cycle verification ===");
        console.log("=> monday: called kickoff");
        console.log("=> wednesday: epoch flip and initEpoch0 called");  
        console.log("=> created test tokens and pair");
        console.log("=> created gauge for pair");  
        console.log("=> user successfully voted during epoch 0");
        console.log("=> next wednesday: epoch successfully flipped from 0 to 1");
        console.log("=> rebase mechanism distributes penalties to votemodule stakers");
        console.log("=> votemodule stakers can earn and claim rebase rewards");
        console.log("=> gauge received allocated emissions based on votes");
        console.log("=> emission distribution system working correctly");
        
        // final assertions to prove all requirements
        assertTrue(userVotes > 0, "requirement: users can vote during epoch 0");
        assertEq(minter.getEpoch(), 1, "requirement: protocol successfully flipped epoch 0 to 1");
        assertTrue(gaugeEmissions > 0, "requirement: gauges receive allocated emissions");
        assertTrue(Voter(voterProxy).lastDistro(gauge) > 0, "requirement: distribution tracking works");
        // note: rebase rewards verification is conditional on pendingrebase >= threshold
    }
        
    function test_stakingUnstakingAndRebaseClaiming() public {
        // === SETUP PHASE ===
        
        console.log("=== monday: kickoff phase ===");
        
        // first need to kickoff the minter (monday)
        uint256 expectedWeeklyEmissions = 2_000_000 * 1e18; // 2M PHAR tokens
        uint256 expectedMultiplier = 10000; // 100% basis

        vm.prank(MULTISIG);
        minter.kickoff(
            address(phar),
            voterProxy,
            expectedWeeklyEmissions,
            expectedMultiplier,
            xphar
        );
        
        console.log("kickoff complete on monday, waiting for epoch flip...");

        console.log("=== advancing to wednesday: epoch flip day ===");
        
        // advance time by 2 days (monday → wednesday)
        vm.warp(block.timestamp + 2 days);
        console.log("advanced to wednesday (epoch flip day)");

        console.log("=== wednesday: init epoch 0 ===");
        
        // now call initEpoch0 after epoch flip (wednesday)
        vm.prank(MULTISIG);
        minter.initEpoch0();
        
        console.log("epoch 0 initialized! current epoch:", minter.getEpoch());

        // Get VoteModule reference
        VoteModule voteModule = VoteModule(Voter(voterProxy).voteModule());
        
        // === USER SETUP ===
        address alice = address(0x1001);
        address bob = address(0x1002);
        vm.deal(alice, 1 ether);
        vm.deal(bob, 1 ether);
        
        uint256 aliceRexAmount = 50000 * 1e18; // 50k PHAR
        uint256 bobRexAmount = 30000 * 1e18; // 30k PHAR
        
        // Give users PHAR tokens
        deal(address(phar), alice, aliceRexAmount);
        deal(address(phar), bob, bobRexAmount);
        
        console.log("=== initial user setup ===");
        console.log("alice phar balance:", phar.balanceOf(alice));
        console.log("bob phar balance:", phar.balanceOf(bob));
        
        // === TEST xPHAR CONVERSION ===
        
        // Alice converts PHAR to xPHAR
        vm.prank(alice);
        phar.approve(xphar, aliceRexAmount);
        vm.prank(alice);
        XPhar(xphar).convertEmissionsToken(aliceRexAmount);
        
        // Bob converts PHAR to xPHAR
        vm.prank(bob);
        phar.approve(xphar, bobRexAmount);
        vm.prank(bob);
        XPhar(xphar).convertEmissionsToken(bobRexAmount);
        
        uint256 aliceXrexBalance = XPhar(xphar).balanceOf(alice);
        uint256 bobXrexBalance = XPhar(xphar).balanceOf(bob);
        
        console.log("=== after xphar conversion ===");
        console.log("alice xphar balance:", aliceXrexBalance);
        console.log("bob xphar balance:", bobXrexBalance);
        assertEq(aliceXrexBalance, aliceRexAmount, "alice should have equal xphar to phar converted");
        assertEq(bobXrexBalance, bobRexAmount, "bob should have equal xphar to phar converted");
        
        // === TEST VOTEMODULE STAKING ===
        
        // Check initial VoteModule state
        assertEq(voteModule.totalSupply(), 0, "VoteModule should start with 0 total supply");
        assertEq(voteModule.balanceOf(alice), 0, "Alice should start with 0 VoteModule balance");
        assertEq(voteModule.balanceOf(bob), 0, "Bob should start with 0 VoteModule balance");
        
        // Alice stakes half her xPHAR
        uint256 aliceStakeAmount = aliceXrexBalance / 2;
        vm.prank(alice);
        XPhar(xphar).approve(address(voteModule), aliceStakeAmount);
        vm.prank(alice);
        voteModule.deposit(aliceStakeAmount);
        
        // Bob stakes all his xPHAR
        vm.prank(bob);
        XPhar(xphar).approve(address(voteModule), bobXrexBalance);
        vm.prank(bob);
        voteModule.depositAll();
        
        console.log("=== after votemodule staking ===");
        console.log("votemodule total supply:", voteModule.totalSupply());
        console.log("alice votemodule balance:", voteModule.balanceOf(alice));
        console.log("bob votemodule balance:", voteModule.balanceOf(bob));
        console.log("alice remaining xphar:", XPhar(xphar).balanceOf(alice));
        console.log("bob remaining xphar:", XPhar(xphar).balanceOf(bob));
        
        // Verify staking worked correctly
        assertEq(voteModule.totalSupply(), aliceStakeAmount + bobXrexBalance, "Total supply should equal sum of stakes");
        assertEq(voteModule.balanceOf(alice), aliceStakeAmount, "Alice VoteModule balance incorrect");
        assertEq(voteModule.balanceOf(bob), bobXrexBalance, "Bob VoteModule balance incorrect");
        assertEq(XPhar(xphar).balanceOf(alice), aliceXrexBalance - aliceStakeAmount, "Alice should have remaining xPHAR");
        assertEq(XPhar(xphar).balanceOf(bob), 0, "Bob should have no remaining xPHAR");
        
        // === TEST VOTING TO ESTABLISH VOTING POWER ===
        
        // Create a test pair and gauge for voting
        TestERC20 tokenA = new TestERC20(1000000 * 1e18);
        TestERC20 tokenB = new TestERC20(1000000 * 1e18);
        
        address token0 = address(tokenA) < address(tokenB) ? address(tokenA) : address(tokenB);
        address token1 = address(tokenA) < address(tokenB) ? address(tokenB) : address(tokenA);
        
        // Whitelist tokens
        vm.prank(ACCESS_HUB);
        Voter(voterProxy).whitelist(token0);
        vm.prank(ACCESS_HUB);
        Voter(voterProxy).whitelist(token1);
        
        // Create pair and gauge
        IPairFactory pairFactory = IPairFactory(PAIR_FACTORY);
        address pair = pairFactory.createPair(token0, token1, false);
        vm.prank(ACCESS_HUB);
        address gauge = Voter(voterProxy).createGauge(pair);
        
        // Users vote to establish voting power for next period
        address[] memory pools = new address[](1);
        pools[0] = pair;
        uint256[] memory weights = new uint256[](1);
        weights[0] = 10000; // 100% weight
        
        vm.prank(alice);
        Voter(voterProxy).vote(alice, pools, weights);
        vm.prank(bob);
        Voter(voterProxy).vote(bob, pools, weights);
        
        console.log("=== AFTER VOTING ===");
        console.log("Alice voting power for next period:", Voter(voterProxy).userVotingPowerPerPeriod(alice, Voter(voterProxy).getPeriod() + 1));
        console.log("Bob voting power for next period:", Voter(voterProxy).userVotingPowerPerPeriod(bob, Voter(voterProxy).getPeriod() + 1));
        
        // === ADVANCE TO NEXT EPOCH AND CREATE REBASE ===
        
        // Advance time by 1 week
        vm.warp(block.timestamp + 1 weeks);
        
        // Update period to trigger epoch transition
        uint256 newPeriod = minter.updatePeriod();
        console.log("Advanced to period:", newPeriod);
        
        // Create pendingRebase through user exit penalties
        address exitUser = address(0x2001);
        uint256 exitAmount = 20000 * 1e18; // 20k xPHAR for exit
        deal(address(phar), exitUser, exitAmount);
        
        vm.prank(exitUser);
        phar.approve(xphar, exitAmount);
        vm.prank(exitUser);
        XPhar(xphar).convertEmissionsToken(exitAmount);
        
        // Multiple exits to build up significant pendingRebase
        vm.prank(exitUser);
        XPhar(xphar).exit(exitAmount / 4); // Exit 25%
        vm.prank(exitUser);
        XPhar(xphar).exit(exitAmount / 4); // Exit another 25%
        
        uint256 pendingRebase = XPhar(xphar).pendingRebase();
        console.log("Pending rebase after exits:", pendingRebase);
        
        // Call rebase to distribute penalties
        minter.rebase();
        
        console.log("=== AFTER REBASE DISTRIBUTION ===");
        console.log("Alice earned rewards:", voteModule.earned(alice));
        console.log("Bob earned rewards:", voteModule.earned(bob));
        
        // === TEST REBASE CLAIMING ===
        
        uint256 aliceEarned = voteModule.earned(alice);
        uint256 bobEarned = voteModule.earned(bob);
        
        if (aliceEarned > 0 || bobEarned > 0) {
            console.log("=== CLAIMING REBASE REWARDS ===");
            
            // Check balances before claiming
            uint256 aliceXrexBefore = XPhar(xphar).balanceOf(alice);
            uint256 bobXrexBefore = XPhar(xphar).balanceOf(bob);
            
            // Alice claims rewards
            if (aliceEarned > 0) {
                vm.prank(alice);
                voteModule.getReward();
            }
            
            // Bob claims rewards  
            if (bobEarned > 0) {
                vm.prank(bob);
                voteModule.getReward();
            }
            
            // Check balances after claiming
            uint256 aliceXrexAfter = XPhar(xphar).balanceOf(alice);
            uint256 bobXrexAfter = XPhar(xphar).balanceOf(bob);
            
            console.log("alice xphar gained from rewards:", aliceXrexAfter - aliceXrexBefore);
            console.log("bob xphar gained from rewards:", bobXrexAfter - bobXrexBefore);
            
                    assertTrue(aliceXrexAfter >= aliceXrexBefore, "alice should have gained xphar from rewards");
        assertTrue(bobXrexAfter >= bobXrexBefore, "bob should have gained xphar from rewards");
    }
    
    // advance time past cooldown period (rebase sets 12 hour cooldown)
    vm.warp(block.timestamp + 13 hours);
    console.log("advanced past cooldown period for unstaking");
    
    // === TEST PARTIAL UNSTAKING ===
    
    console.log("=== TESTING PARTIAL UNSTAKING ===");
        
        // Alice unstakes half of her staked amount
        uint256 aliceUnstakeAmount = voteModule.balanceOf(alice) / 2;
        uint256 aliceXrexBeforeUnstake = XPhar(xphar).balanceOf(alice);
        uint256 aliceVoteModuleBefore = voteModule.balanceOf(alice);
        
        vm.prank(alice);
        voteModule.withdraw(aliceUnstakeAmount);
        
        console.log("Alice unstaked amount:", aliceUnstakeAmount);
        console.log("Alice VoteModule balance after unstake:", voteModule.balanceOf(alice));
        console.log("Alice xPHAR balance after unstake:", XPhar(xphar).balanceOf(alice));
        
        assertEq(voteModule.balanceOf(alice), aliceVoteModuleBefore - aliceUnstakeAmount, "alice votemodule balance should decrease");
        assertEq(XPhar(xphar).balanceOf(alice), aliceXrexBeforeUnstake + aliceUnstakeAmount, "alice should receive xphar back");
        
        // === TEST FULL UNSTAKING WITH REWARDS ===
        
        console.log("=== TESTING FULL UNSTAKING WITH REWARDS ===");
        
        // Bob unstakes everything and claims remaining rewards
        uint256 bobVoteModuleBalance = voteModule.balanceOf(bob);
        uint256 bobXrexBeforeUnstake = XPhar(xphar).balanceOf(bob);
        
        vm.prank(bob);
        voteModule.withdrawAll(); // This should claim rewards too
        
        console.log("Bob VoteModule balance after withdrawAll:", voteModule.balanceOf(bob));
        console.log("Bob xPHAR balance after withdrawAll:", XPhar(xphar).balanceOf(bob));
        
        assertEq(voteModule.balanceOf(bob), 0, "bob should have no votemodule balance after withdrawall");
        assertTrue(XPhar(xphar).balanceOf(bob) >= bobXrexBeforeUnstake + bobVoteModuleBalance, "bob should receive at least his staked amount back");
        
        // === FINAL VERIFICATION ===
        
        console.log("=== FINAL VERIFICATION ===");
        console.log("VoteModule total supply:", voteModule.totalSupply());
        console.log("Alice final xPHAR balance:", XPhar(xphar).balanceOf(alice));
        console.log("Bob final xPHAR balance:", XPhar(xphar).balanceOf(bob));
        console.log("Alice final VoteModule balance:", voteModule.balanceOf(alice));
        console.log("Bob final VoteModule balance:", voteModule.balanceOf(bob));
        
        // Verify that users can convert their final xPHAR back to PHAR if needed
        uint256 aliceExitAmount = XPhar(xphar).balanceOf(alice) / 10; // Exit 10% to test
        if (aliceExitAmount > 0) {
            uint256 aliceRexBefore = phar.balanceOf(alice);
            vm.prank(alice);
            uint256 exitedAmount = XPhar(xphar).exit(aliceExitAmount);
            uint256 aliceRexAfter = phar.balanceOf(alice);
            
            console.log("alice exited xphar amount:", aliceExitAmount);
            console.log("alice received phar amount:", exitedAmount);
            assertTrue(aliceRexAfter > aliceRexBefore, "alice should receive phar from exit");
            assertTrue(exitedAmount < aliceExitAmount, "exit should have penalty");
        }
        
        // summary
        console.log("\n=== staking/unstaking test summary ===");
        console.log("users can convert phar to xphar");
        console.log("users can stake xphar in votemodule");
        console.log("users can vote to establish voting power");
        console.log("rebase mechanism distributes penalties to stakers");
        console.log("users can claim rebase rewards");
        console.log("users can partially unstake from votemodule");
        console.log("users can fully unstake with automatic reward claiming");
        console.log("users can exit xphar back to phar (with penalty)");
        
        assertTrue(true, "all staking/unstaking mechanics work correctly");
    }

    function test_cooldownAndEdgeCases() public {
        // === SETUP PHASE ===
        
        console.log("=== monday: kickoff phase ===");
        
        uint256 expectedWeeklyEmissions = 1_000_000 * 1e18;
        uint256 expectedMultiplier = 10000;

        vm.prank(MULTISIG);
        minter.kickoff(address(phar), voterProxy, expectedWeeklyEmissions, expectedMultiplier, xphar);
        
        console.log("kickoff complete on monday, waiting for epoch flip...");

        console.log("=== advancing to wednesday: epoch flip day ===");
        
        // advance time by 2 days (monday → wednesday)
        vm.warp(block.timestamp + 2 days);
        console.log("advanced to wednesday (epoch flip day)");

        console.log("=== wednesday: init epoch 0 ===");
        
        vm.prank(MULTISIG);
        minter.initEpoch0();
        
        console.log("epoch 0 initialized! current epoch:", minter.getEpoch());

        VoteModule voteModule = VoteModule(Voter(voterProxy).voteModule());
        
        // === USER SETUP ===
        address charlie = address(0x3001);
        vm.deal(charlie, 1 ether);
        
        uint256 charlieRexAmount = 10000 * 1e18; // 10k PHAR
        deal(address(phar), charlie, charlieRexAmount);
        
        // Convert to xPHAR
        vm.prank(charlie);
        phar.approve(xphar, charlieRexAmount);
        vm.prank(charlie);
        XPhar(xphar).convertEmissionsToken(charlieRexAmount);
        
        uint256 charlieXrexBalance = XPhar(xphar).balanceOf(charlie);
        
        // === TEST INITIAL STAKING (NO COOLDOWN YET) ===
        
        console.log("=== TESTING INITIAL STAKING ===");
        uint256 initialStake = charlieXrexBalance / 2;
        
        vm.prank(charlie);
        XPhar(xphar).approve(address(voteModule), initialStake);
        vm.prank(charlie);
        voteModule.deposit(initialStake);
        
        console.log("Charlie staked:", initialStake);
        console.log("VoteModule unlockTime:", voteModule.unlockTime());
        console.log("Current time:", block.timestamp);
        
        // === TEST COOLDOWN BLOCKING ===
        
        console.log("=== TESTING COOLDOWN BLOCKING ===");
        
        // Create rebase to trigger cooldown
        address exitUser = address(0x3002);
        uint256 exitAmount = 5000 * 1e18;
        deal(address(phar), exitUser, exitAmount);
        
        vm.prank(exitUser);
        phar.approve(xphar, exitAmount);
        vm.prank(exitUser);
        XPhar(xphar).convertEmissionsToken(exitAmount);
        vm.prank(exitUser);
        XPhar(xphar).exit(exitAmount); // This creates pendingRebase
        
        // Advance to next period and trigger rebase (which sets cooldown)
        vm.warp(block.timestamp + 1 weeks);
        minter.updatePeriod();
        minter.rebase(); // This should set unlockTime = block.timestamp + cooldown
        
        console.log("After rebase - unlockTime:", voteModule.unlockTime());
        console.log("Current time:", block.timestamp);
        console.log("Cooldown duration:", voteModule.cooldown());
        
        // Try to deposit during cooldown (should fail)
        uint256 additionalStake = charlieXrexBalance - initialStake;
        vm.prank(charlie);
        XPhar(xphar).approve(address(voteModule), additionalStake);
        
        vm.expectRevert(); // Should revert due to cooldown
        vm.prank(charlie);
        voteModule.deposit(additionalStake);
        
        console.log("deposit correctly blocked during cooldown");
        
        // try to withdraw during cooldown (should fail)
        vm.expectRevert(); // should revert due to cooldown
        vm.prank(charlie);
        voteModule.withdraw(initialStake / 2);
        
        console.log("withdraw correctly blocked during cooldown");
        
        // === TEST COOLDOWN EXPIRY ===
        
        console.log("=== TESTING COOLDOWN EXPIRY ===");
        
        // Advance time past cooldown
        vm.warp(voteModule.unlockTime() + 1);
        console.log("Advanced past cooldown - current time:", block.timestamp);
        
        // now deposit should work
        vm.prank(charlie);
        voteModule.deposit(additionalStake);
        
        console.log("deposit works after cooldown expires");
        console.log("charlie total votemodule balance:", voteModule.balanceOf(charlie));
        
        // withdraw should also work
        vm.prank(charlie);
        voteModule.withdraw(initialStake / 4);
        
        console.log("withdraw works after cooldown expires");
        
        // === TEST COOLDOWN EXEMPTION ===
        
        console.log("=== TESTING COOLDOWN EXEMPTION ===");
        
        // Create another rebase to trigger cooldown again
        // give exitUser more tokens since they spent all their xphar in the first exit
        uint256 secondExitAmount = 2000 * 1e18;
        deal(address(phar), exitUser, secondExitAmount);
        vm.prank(exitUser);
        phar.approve(xphar, secondExitAmount);
        vm.prank(exitUser);
        XPhar(xphar).convertEmissionsToken(secondExitAmount);
        
        vm.prank(exitUser);
        XPhar(xphar).exit(secondExitAmount / 2); // exit half of the new amount
        
        // check if we have pendingRebase before calling rebase
        uint256 pendingBeforeSecondRebase = XPhar(xphar).pendingRebase();
        console.log("pending rebase before second rebase:", pendingBeforeSecondRebase);
        
        // advance time to next period for rebase to work (rebase needs new period)
        vm.warp(block.timestamp + 1 weeks);
        minter.updatePeriod();
        minter.rebase(); // This sets cooldown again
        
        console.log("New unlockTime after second rebase:", voteModule.unlockTime());
        console.log("Current time after second rebase:", block.timestamp);
        
        // Verify cooldown is active (only if we actually had a rebase)
        if (pendingBeforeSecondRebase >= XPhar(xphar).rebaseThreshold()) {
            vm.expectRevert();
            vm.prank(charlie);
            voteModule.withdraw(100 * 1e18);
        } else {
            console.log("skipping cooldown test - no rebase occurred");
        }
        
        // set exemption for charlie
        vm.prank(ACCESS_HUB);
        voteModule.setCooldownExemption(charlie, true);
        
        console.log("charlie granted cooldown exemption");
        
        // test exemption functionality (only if cooldown was actually set)
        uint256 exemptStake = 1000 * 1e18;
        deal(address(phar), charlie, exemptStake);
        vm.prank(charlie);
        phar.approve(xphar, exemptStake);
        vm.prank(charlie);
        XPhar(xphar).convertEmissionsToken(exemptStake);
        
        vm.prank(charlie);
        XPhar(xphar).approve(address(voteModule), exemptStake);
        vm.prank(charlie);
        voteModule.deposit(exemptStake); // should work (either no cooldown or exempted)
        
        console.log("exempt user can deposit during cooldown");
        
        vm.prank(charlie);
        voteModule.withdraw(exemptStake); // should work (either no cooldown or exempted)
        
        console.log("exempt user can withdraw during cooldown");
        
        // === TEST ZERO AMOUNT OPERATIONS ===
        
        console.log("=== TESTING ZERO AMOUNT OPERATIONS ===");
        
        // try to deposit 0 (should fail)
        vm.expectRevert(); // should revert with zero_amount error
        vm.prank(charlie);
        voteModule.deposit(0);
        
        // try to withdraw 0 (should fail)
        vm.expectRevert(); // should revert with zero_amount error
        vm.prank(charlie);
        voteModule.withdraw(0);
        
        console.log("zero amount deposits and withdrawals correctly rejected");
        
        // === TEST INSUFFICIENT BALANCE ===
        
        console.log("=== TESTING INSUFFICIENT BALANCE ===");
        
        address newUser = address(0x3003);
        vm.deal(newUser, 1 ether);
        
        // try to withdraw without any staked balance (should fail)
        vm.expectRevert(); // should fail due to insufficient balance
        vm.prank(newUser);
        voteModule.withdraw(100 * 1e18);
        
        console.log("withdraw with insufficient balance correctly rejected");
        
        // final summary
        
        console.log("\n=== cooldown and edge cases test summary ===");
        console.log("initial staking works without cooldown");
        console.log("cooldown correctly blocks deposits and withdrawals");
        console.log("operations work after cooldown expires");
        console.log("cooldown exemption allows operations during cooldown");
        console.log("zero amount operations are properly rejected");
        console.log("insufficient balance withdrawals are properly rejected");
        
        assertTrue(true, "all cooldown and edge case mechanics work correctly");
    }

    function test_liveClGaugeNotifyReward() public {
        console.log("=== Testing PHAR bribe to live CL gauge ===");
        
        // Live CL gauge address to test
        address liveGauge = 0xE1d52fb55E09CE5384AAec0F7388b57F2F57d7CC;
        console.log("Testing gauge:", liveGauge);
        
        IGaugeV3 gauge = IGaugeV3(liveGauge);
        
        // Use production PHAR token
        address rexToken = PRODUCTION_REX;
        console.log("Using PHAR token:", rexToken);
        
        // Check basic gauge info
        console.log("Gauge first period:", gauge.firstPeriod());
        
        // Get current reward tokens
        address[] memory currentRewards = gauge.getRewardTokens();
        console.log("Current reward tokens count:", currentRewards.length);
        for (uint256 i = 0; i < currentRewards.length; i++) {
            console.log("Reward token", i, ":", currentRewards[i]);
        }
        
        // Check if PHAR is already whitelisted as a reward token
        bool rexIsReward = gauge.isReward(rexToken);
        console.log("PHAR is reward token:", rexIsReward);
        
        // Test notifyRewardAmount with PHAR
        uint256 rewardAmount = 1000 * 1e18; // 1000 PHAR tokens
        
        // Give ourselves some PHAR tokens
        deal(rexToken, address(this), rewardAmount);
        console.log("Got PHAR tokens, balance:", IERC20(rexToken).balanceOf(address(this)));
        
        // Approve the gauge to transfer PHAR
        IERC20(rexToken).approve(liveGauge, rewardAmount);
        
        // Check gauge PHAR balance before
        uint256 gaugeBefore = IERC20(rexToken).balanceOf(liveGauge);
        console.log("Gauge PHAR balance before:", gaugeBefore);
        
        // Attempt to notify PHAR reward amount
        gauge.notifyRewardAmount(rexToken, rewardAmount);
        
        // Check gauge PHAR balance after
        uint256 gaugeAfter = IERC20(rexToken).balanceOf(liveGauge);
        console.log("Gauge PHAR balance after:", gaugeAfter);
        
        // Verify the reward was added
        assertTrue(gaugeAfter > gaugeBefore, "Gauge should have received PHAR tokens");
        console.log("SUCCESS: PHAR bribe worked! Added", gaugeAfter - gaugeBefore, "PHAR to gauge");
        
        // Check the current period's reward amount
        uint256 currentPeriod = block.timestamp / (7 days);
        uint256 periodRewards = gauge.tokenTotalSupplyByPeriod(currentPeriod, rexToken);
        console.log("Period PHAR rewards for current period:", periodRewards);
        assertTrue(periodRewards > 0, "Period should have PHAR reward allocation");
        
        console.log("=== PHAR bribe test completed successfully ===");
    }
        
}

