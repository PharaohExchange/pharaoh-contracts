import { ethers, network, run } from "hardhat";
import { deploy } from "./deployment";
import { setBalance } from "@nomicfoundation/hardhat-network-helpers";
import { V1Contracts, createPair, e } from "./helpers";
import { IWETH9, Token, WETH9 } from "../typechain-types";
import { CoreConfig } from "./deployment";

export async function deployERC20(amount: bigint) {
  const ERC20 = await ethers.getContractFactory("Token");
  const token = await ERC20.deploy(amount);
  await token.waitForDeployment();

  return token as Token;
}
export async function deployWETH9() {
  const ERC20 = await ethers.getContractFactory(
    "contracts/mock/WETH9.sol:WETH9",
  );
  const token = (await ERC20.deploy()) as WETH9;
  await token.waitForDeployment();

  if (network.name == "local" || network.name == "hardhat") {
    await setBalance((await ethers.getSigners())[0].address, ethers.MaxUint256);
    await token.deposit({ value: e(100_000_000) });
  }

  return token as IWETH9;
}

export async function testDeploy() {
  // initialize addresses
  const [deployer] = await ethers.getSigners();
  await setBalance(deployer.address, ethers.parseEther("10000"));
  const msig = deployer.address;

  // deploy tokens
  const weth = await deployWETH9();
  const usdc = await deployERC20(100n * (10n ** 18n));
  const usdt = await deployERC20(100n * (10n ** 18n));
  const dei = await deployERC20(100n * (10n ** 18n));
  const deus = await deployERC20(100n * (10n ** 18n));
  const wbtc = await deployERC20(100n * (10n ** 18n));

  const testConfig = {
    INITIAL_SUPPLY: ethers.parseEther("100000000"),
    MULTISIG: msig,
    WETH: await weth.getAddress(),
    INCENTIVE_GROWTH: ethers.parseEther("250"),
    FEE_SETTER: msig,
    SALTS: [
      1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21,
      22, 23, 24,
    ],
    WHITELIST_TOKENS: await Promise.all([
      weth.getAddress(),
      usdc.getAddress(),
      usdt.getAddress(),
      dei.getAddress(),
      deus.getAddress(),
      wbtc.getAddress(),
    ]),
    EMISSIONS_TOKEN_SALT: 1,
  };

  const core = await deploy(testConfig);

  const ram = core.ram;

  const tokens = {
    ram,
    weth,
    usdc,
    usdt,
    dei,
    deus,
    wbtc,
  };
  /*
    // approve tokens to router
    for (const token of Object.values(tokens)) {
        await token.approve(cleopatra.router.address, MAX_UINT);
    }

    // approve ra to voting escrow
    await ra.approve(cleopatra.votingEscrow.address, MAX_UINT);

    const pools = [
        [ra.address, weth.address, false, e(10e6), e(100)],
        [usdc.address, weth.address, false, e(150000), e(100)],
        [usdc.address, deus.address, false, e(100000), e(2000)],
        [usdc.address, usdt.address, true, e(1e6), e(1e6)],
        [usdc.address, dei.address, true, e(1e6), e(1e6)],
    ];

    // create pairs
    for (const pool of pools) {
        await cleopatra.router.addLiquidity(
            // @ts-ignore
            ...pool,
            0,
            0,
            deployer.address,
            Date.now()
        );

        const pairAddress = await cleopatra.pairFactory.getPair(
            // @ts-ignore
            pool[0],
            pool[1],
            pool[2]
        );
        await cleopatra.voter.createGauge(pairAddress);
    }
*/
  return {
    ...tokens,
    ...core,
  };
}

export type TestDeploy = Awaited<ReturnType<typeof testDeploy>>;
