import "@nomicfoundation/hardhat-foundry";
import "@nomicfoundation/hardhat-toolbox";
import { HardhatUserConfig } from "hardhat/config";
// import "@openzeppelin/hardhat-upgrades";

import { config as dotenvConfig } from "dotenv";
import { resolve } from "path";
dotenvConfig({ path: resolve(__dirname, "./.env") });

// import "hardhat-contract-sizer";
// import "@nomiclabs/hardhat-solhint";
//import "@nomicfoundation/hardhat-ignition-ethers";
//import "@nomicfoundation/hardhat-foundry";

const POOL_COMPILER_SETTINGS = {
    version: "0.8.26",
    settings: {
        viaIR: true,
        optimizer: {
            enabled: true,
            runs: 200,
        },
        evmVersion: "cancun",
        metadata: {
            bytecodeHash: "none",
        },
    },
};

const accounts = process.env.PRIVATE_KEY
    ? [process.env.PRIVATE_KEY]
    : undefined;

const voterCompilerSettings = {
    version: "0.8.28",
    settings: {
        optimizer: {
            enabled: true,
            runs: 200,
        },
        evmVersion: "cancun",
        viaIR: true,
        metadata: {
            bytecodeHash: "none",
        },
    },
};

const poolDeployerCompilerSettings = {
    version: "0.8.28",
    settings: {
        optimizer: {
            enabled: true,
            runs: 200,
        },
        evmVersion: "cancun",
        viaIR: true,
        // metadata: {
        //     bytecodeHash: "none",
        // },
    },
};

const config: HardhatUserConfig = {
    solidity: {
        compilers: [
            {
                version: "0.4.18",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 200,
                    },
                    evmVersion: "cancun",
                    metadata: {
                        bytecodeHash: "none",
                    },
                },
            },
            // {
            //     version: "0.8.26",
            //     settings: {
            //         optimizer: {
            //             enabled: true,
            //             runs: 800,
            //         },
            //         viaIR: true,
            //         metadata: {
            //             // do not include the metadata hash, since this is machine dependent
            //             // and we want all generated code to be deterministic
            //             // https://docs.soliditylang.org/en/v0.7.6/metadata.html
            //             bytecodeHash: "none",
            //         },
            //     },
            // },
            {
                version: "0.8.28",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 200,
                    },
                    evmVersion: "cancun",
                    viaIR: true,
                    // metadata: {
                    //     bytecodeHash: "none",
                    // },
                },
            },
            // {
            //     version: "0.8.17",

            // }
        ],
        overrides: {
            "contracts/Voter.sol": voterCompilerSettings,
            "contracts/libraries/RewardClaimers.sol": voterCompilerSettings,
            "contracts/CL/core/RamsesV3PoolDeployer.sol":
                poolDeployerCompilerSettings,
            "contracts/CL/core/RamsesV3Pool.sol":
                poolDeployerCompilerSettings,
        },
    },

    networks: {
        hardhat: {
            chainId: 250,
            initialBaseFeePerGas: 0,
            allowUnlimitedContractSize: true,
        },
        localhost: {
            accounts: accounts,
        },
        fantom: {
            url: process.env.RPC ?? "https://rpc3.fantom.network",
            accounts: accounts,
        },
        sonic: {
            url: process.env.RPC ?? "https://rpc.soniclabs.com",
            accounts: accounts,
            chainId: 146,
        },
        frame: {
            url: "http://127.0.0.1:1248",
            chainId: 146,
        },
        hyperevm: {
            url: process.env.HYPEREVM_RPC ?? "https://api.hyperliquid-testnet.xyz/evm",
            accounts: accounts,
            chainId: 999,
        }
    },

    etherscan: {
        apiKey: {
            fantom: process.env.API_KEY!,
            // sonic: "",
            hyperevm: "abc", // blockscout doesn't require a real API key
        },
        customChains: [
            {
                network: "sonic",
                chainId: 146,
                urls: {
                    apiURL: "https://api.sonicscan.org/api",
                    browserURL: "https://sonicscan.org",
                },
            },
            {
                network: "hyperevm",
                chainId: 999,
                urls: {
                    apiURL: process.env.HYPERSCAN_URL || "https://explorer.hyperliquid-testnet.xyz/api",
                    browserURL: process.env.HYPERSCAN_URL?.replace('/api', '') || "https://explorer.hyperliquid-testnet.xyz",
                },
            },
        ],
    },

    gasReporter: {
        enabled: process.env.REPORT_GAS?.toLowerCase() == "true",
    },

    paths: {
        sources: "contracts",
        tests: "test/v3",
    },
};

export default config;
