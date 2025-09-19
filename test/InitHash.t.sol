// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

interface MachineXV3Factory {
    function getPool(address token0, address token1, int24 tickSpacing) external view returns (address pool);
}

interface MachineXV3PoolDeployer {
    function poolBytecode() external view returns (bytes memory);
}

contract Create2AddressTest is Test {
    // this is the hash that works in practice based on transaction trace analysis, 
    // and also what our calculateRealPoolInitCodeHash() should compute.
    bytes32 constant EXPECTED_POOL_INIT_CODE_HASH = 0x892f127ed4b26ca352056c8fb54585a3268f76f97fdd84d5836ef4bda8d8c685;
    // modified to accept poolInitHash as a parameter for testing different hash calculation methods
    function computeAddress(address deployer, address token0, address token1, int24 tickSpacing, bytes32 poolInitHash) internal pure returns (address pool) {
        require(token0 < token1, "!TokenOrder");
        pool = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex'ff',
                            deployer,
                            keccak256(abi.encode(token0, token1, tickSpacing)),
                            poolInitHash
                        )
                    )
                )
            )
        );
    }
    
    // this function calculates the POOL_INIT_CODE_HASH based on the MachineXV3PoolDeployer's create2 init code construction logic
    function calculateRealPoolInitCodeHash() internal pure returns (bytes32) {
        // part 1 of the init code (32 bytes) from MachineXV3PoolDeployer assembly
        bytes memory part1 = hex"638a3f6b0460e01b60005260006000600460006000335af16000600060006000";
        // the 23-byte value that gets shifted, represented as a uint256
        uint256 valueToShift = 0x60003d600060003e6000515af43d600060003e3d6000f3;
        // shl(72, valueToShift) as per MachineXV3PoolDeployer assembly
        uint256 shiftedValue = valueToShift << 72;
        // we need the first 23 bytes of the 32-byte shiftedValue for the second part of the init code
        bytes memory shiftedValueBytes = abi.encodePacked(shiftedValue); // 32 bytes total
        bytes memory part2 = new bytes(23); // the create2 call uses 55 bytes total (32 from part1 + 23 from part2)
        for (uint i = 0; i < 23; i++) {
            part2[i] = shiftedValueBytes[i];
        }
        bytes memory combinedInitCode = abi.encodePacked(part1, part2); // total 55 bytes
        return keccak256(combinedInitCode);
    }

    function test_comparePoolAddressCalculationMethods() public {
        address V3_POOL_DEPLOYER = 0x2Bef16A0081565E72100D73CBe19B1Bd2d802380;
        address V3_FACTORY = 0xA87c8308722237F6442Ef4762B7287afB84fB191;
        address token0 = 0x5555555555555555555555555555555555555555; 
        address token1 = 0xB8CE59FC3717ada4C02eaDF9682A9e934F625ebb;
        int24 tickSpacing = 100;

        // get the actual pool address from the factory
        address factoryPool = MachineXV3Factory(V3_FACTORY).getPool(token0, token1, tickSpacing);
        // from CREATE2 debugTrace (hardcoded known POOL_INIT_CODE_HASH)
        bytes32 hashFromDebugTrace = EXPECTED_POOL_INIT_CODE_HASH;
        address addressFromDebugTrace = computeAddress(V3_POOL_DEPLOYER, token0, token1, tickSpacing, hashFromDebugTrace);
        // from univ3 method (classic keccak256 of the creation code returned by poolBytecode())
        bytes memory poolCreationCode = MachineXV3PoolDeployer(V3_POOL_DEPLOYER).poolBytecode();
        bytes32 hashFromUniv3Method = keccak256(poolCreationCode);
        address addressFromUniv3Method = computeAddress(V3_POOL_DEPLOYER, token0, token1, tickSpacing, hashFromUniv3Method);
        // from our method (reverse-engineered calculation from deployer's assembly)
        bytes32 hashFromOurMethod = calculateRealPoolInitCodeHash();
        address addressFromOurMethod = computeAddress(V3_POOL_DEPLOYER, token0, token1, tickSpacing, hashFromOurMethod);
        // logs 
        console.log("--- Init Code Hashes ---");
        console.log("From CREATE2 debugTrace:", vm.toString(hashFromDebugTrace));
        console.log("From univ3 method:      ", vm.toString(hashFromUniv3Method));
        console.log("From our method:        ", vm.toString(hashFromOurMethod));
        assertTrue(hashFromDebugTrace == hashFromOurMethod, "Calculated hash from our method should match hash from debug trace");

        console.log("\n--- Pool Addresses ---");
        console.log("Actual Factory Pool:          ", factoryPool);
        console.log("Address from CREATE2 debugTrace:", addressFromDebugTrace);
        console.log("Address from univ3 method:      ", addressFromUniv3Method);
        console.log("Address from our method:        ", addressFromOurMethod);

        // assertions
        assertTrue(addressFromDebugTrace == factoryPool, "Address from CREATE2 debugTrace should match factory pool");
        assertTrue(addressFromUniv3Method != factoryPool, "Address from univ3 method should NOT match factory pool for this deployer");
        assertTrue(addressFromOurMethod == factoryPool, "Address from our method should match factory pool");
        assertTrue(hashFromOurMethod == EXPECTED_POOL_INIT_CODE_HASH, "Hash from our method must match the known correct hash from debug trace");
    }
}