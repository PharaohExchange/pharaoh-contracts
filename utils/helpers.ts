import { expect } from "chai";
import { ethers } from "hardhat";
import {
    ERC20,
    FeeDistributorFactory,
    GaugeFactory,
    Minter,
    PairFactory,
    ContractDeployer,
    RewardsDistributor,
    Router,
    VeArtProxy,
    Ramses,
    Voter,
    VotingEscrow,
    FeeDistributor,
    Gauge,
    Pair,
    IERC20,
    NonfungiblePositionManager,
    ClPoolFactory,
    NonfungibleTokenPositionDescriptor,
    IWETH9,
    XToken,
    CommandCenter,
    ProtocolWhitelist,
} from "../typechain-types";
import {
    getStorageAt,
    setStorageAt,
} from "@nomicfoundation/hardhat-network-helpers";
import { BigNumberish } from "ethers";
import { TestDeploy } from "./testDeployment";
import { bigint } from "hardhat/internal/core/params/argumentTypes";

export type TestTokens = {
    weth: IWETH9;
    usdc: ERC20;
    usdt: ERC20;
    dei: ERC20;
    deus: ERC20;
    wbtc: ERC20;
};

export type V1Contracts = {
    proxyAdminAddress: string;
    contractDeployer: ContractDeployer;
    ram: Ramses;
    gaugeFactory: GaugeFactory;
    feeDistributorFactory: FeeDistributorFactory;
    pairFactory: PairFactory;
    router: Router;
    veArtProxy: VeArtProxy;
    votingEscrow: VotingEscrow;
    rewardsDistributor: RewardsDistributor;
    voter: Voter;
    minter: Minter;
    xRam: XToken;
    CommandCenter: CommandCenter;
    ProtocolWhitelist: ProtocolWhitelist;
};

export type V2Contracts = {
    deployer: ContractDeployer;
    proxyAdminAddress: string;
    factory: ClPoolFactory;
    nfpManager: NonfungiblePositionManager;
    nfpDescriptor: NonfungibleTokenPositionDescriptor;
};

export function e(amount: string | number) {
    return ethers.parseEther(String(amount));
}

export async function createPair(
    c: TestDeploy,
): Promise<[Pair, Gauge, FeeDistributor]> {
    const pair = (await ethers.getContractAt(
        "Pair",
        await c.pairFactory.getPair(
            c.ram.getAddress(),
            c.weth.getAddress(),
            false,
        ),
    )) as Pair;
    const gauge = (await ethers.getContractAt(
        "Gauge",
        await c.voter.gauges(pair.getAddress()),
    )) as Gauge;
    const feeDistributor = (await ethers.getContractAt(
        "FeeDistributor",
        await c.voter.feeDistributors(gauge.getAddress()),
    )) as FeeDistributor;

    return [pair, gauge, feeDistributor];
}

export async function getPair(
    c: any,
    token0Address: string,
    token1Address: string,
    isStable: boolean,
): Promise<{ pair: Pair; gauge: Gauge; feeDistributor: FeeDistributor }> {
    const pair = (await ethers.getContractAt(
        "Pair",
        await c.pairFactory.getPair(token0Address, token1Address, isStable),
    )) as Pair;
    const gauge = (await ethers.getContractAt(
        "Gauge",
        await c.voter.gauges(pair.getAddress()),
    )) as Gauge;
    const feeDistributor = (await ethers.getContractAt(
        "FeeDistributor",
        await c.voter.feeDistributors(gauge.getAddress()),
    )) as FeeDistributor;

    return {
        pair,
        gauge,
        feeDistributor,
    };
}

export async function getBalances(wallet: string, tokens: ERC20[]) {
    const balances: Record<string, bigint> = {};
    for (const token of tokens) {
        balances[await token.symbol()] = await token.balanceOf(wallet);
    }
    return balances;
}

export async function expectBalanceIncrease(
    wallet: string,
    tokens: ERC20[],
    previousBalances: any,
) {
    const newBalances = await getBalances(wallet, tokens);
    for (const token of tokens) {
        const symbol = await token.symbol();
        expect(newBalances[symbol]).greaterThan(previousBalances[symbol]);
    }
}

export async function generateSwapFee(c: any) {
    const [deployer] = await ethers.getSigners();
    await c.router.swapExactTokensForTokens(
        e(10e3),
        0,
        [
            { from: c.ram.address, to: c.weth.address, stable: false },
            { from: c.weth.address, to: c.usdc.address, stable: false },
            { from: c.usdc.address, to: c.usdt.address, stable: true },
        ],
        deployer.address,
        Date.now(),
    );
    await c.router.swapExactTokensForTokens(
        e(1e3),
        0,
        [
            { from: c.usdt.address, to: c.usdc.address, stable: true },
            { from: c.usdc.address, to: c.weth.address, stable: false },
            { from: c.weth.address, to: c.ram.address, stable: false },
        ],
        deployer.address,
        Date.now(),
    );
}

export async function sleep(s: number) {
    console.log("(sleeping for", s, "seconds)");
    return new Promise((resolve) => setTimeout(resolve, s * 1000));
}

function toBytes32(amount: BigNumberish) {
    return ethers.toBeHex(amount, 32);
}

async function findBalanceOfSlot(token: ERC20) {
    const balance = await token.balanceOf(await token.getAddress());
    const newBalance = balance + 1n;

    let slot = BigInt(
        "0x52c63247e1f47db19d5ce0460030c497f067ca4cebf71ba98eeadabe20bace00",
    );
    while (true) {
        const index = ethers
            .solidityPackedKeccak256(
                ["uint256", "uint256"],
                [await token.getAddress(), slot], // key, slot (vyper is reversed)
            )
            .toString();

        const storage = await getStorageAt(await token.getAddress(), index);

        await setStorageAt(
            await token.getAddress(),
            index,
            toBytes32(newBalance),
        );

        if ((await token.balanceOf(await token.getAddress())) == newBalance) {
            break;
        }

        await setStorageAt(await token.getAddress(), index, storage);

        if (
            slot ==
            BigInt(
                "0x52c63247e1f47db19d5ce0460030c497f067ca4cebf71ba98eeadabe20bace00",
            )
        ) {
            slot = 0n;
        } else {
            slot++;
        }
    }

    return slot;
}

export async function setERC20Balance(
    tokenAddress: string,
    userAddress: string,
    balance: bigint,
) {
    const token = (await ethers.getContractAt(
        "@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20",
        tokenAddress,
    )) as any as ERC20;

    // Get storage slot index
    const index = ethers.solidityPackedKeccak256(
        ["uint256", "uint256"],
        [userAddress, await findBalanceOfSlot(token)], // key, slot
    );

    // Manipulate local balance (needs to be bytes32 string)
    await setStorageAt(
        await token.getAddress(),
        index.toString(),
        toBytes32(balance).toString(),
    );
}

export function positionHash(
    owner: string,
    index: BigNumberish,
    tickLower: BigNumberish,
    tickUpper: BigNumberish,
): string {
    return ethers.solidityPackedKeccak256(
        ["address", "uint256", "int24", "int24"],
        [owner, index, tickLower, tickUpper],
    );
}
