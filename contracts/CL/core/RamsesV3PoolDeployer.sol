// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {IRamsesV3PoolDeployer} from "./interfaces/IRamsesV3PoolDeployer.sol";

import {RamsesV3Pool} from "./RamsesV3Pool.sol";
import {IRamsesV3Factory} from "./interfaces/IRamsesV3Factory.sol";

contract RamsesV3PoolDeployer is IRamsesV3PoolDeployer {
    address public immutable RamsesV3Factory;

    address public immutable creationCodeLocation;

    constructor(address _ramsesV3Factory) {
        RamsesV3Factory = _ramsesV3Factory;
        creationCodeLocation = _deployCreationCode();
    }

    /// @dev Deploys a pool with the given parameters by transiently setting the parameters storage slot and then
    /// clearing it after deploying the pool.
    /// @param token0 The first token of the pool by address sort order
    /// @param token1 The second token of the pool by address sort order
    /// @param tickSpacing The tickSpacing of the pool
    function deploy(address token0, address token1, int24 tickSpacing) external returns (address pool) {
        require(msg.sender == RamsesV3Factory);

        bytes32 salt = keccak256(abi.encode(token0, token1, tickSpacing));

        // this ensures POOL_INIT_HASH will never need changing again
        assembly ("memory-safe") {
            mstore(0x00, 0x638a3f6b0460e01b60005260006000600460006000335af16000600060006000)
            mstore(0x20, shl(72, 0x60003d600060003e6000515af43d600060003e3d6000f3))
            pool := create2(0, 0, 55, salt)
        }

        // the above assembly code calls creationCodeLocation() and then delegate calls the address to return
        // the contract bytecode
        // simpler cloning methods won't work as we have immutable states that needs to be initialized in the constructor

        // PUSH4 0x8a3f6b04
        // PUSH1 0xe0
        // SHL
        // PUSH1 0x00
        // MSTORE
        // PUSH1 0x00
        // PUSH1 0x00
        // PUSH1 0x04
        // PUSH1 0x00
        // PUSH1 0x00
        // CALLER
        // GAS
        // CALL
        // PUSH1 0x00
        // PUSH1 0x00
        // PUSH1 0x00
        // PUSH1 0x00
        // PUSH1 0x00
        // RETURNDATASIZE
        // PUSH1 0x00
        // PUSH1 0x00
        // RETURNDATACOPY
        // PUSH1 0x00
        // MLOAD
        // GAS
        // DELEGATECALL
        // RETURNDATASIZE
        // PUSH1 0x00
        // PUSH1 0x00
        // RETURNDATACOPY
        // RETURNDATASIZE
        // PUSH1 0x00
        // RETURN

        // it is equivalent to the below yul code

        // assembly {
        //     mstore(0x00, shl(224, 0x8a3f6b04)) // store creationCodeLocation() signature to memory
        //     call(gas(), caller(), 0, 0, 4, 0, 0) // call creationCodeLocation()
        //     creationCodeLocation := returndatacopy(0x00, 0x00, 0x20) // fetch creationCodeLocation
        //     delegatecall(gas(), creationCodeLocation, 0, 0, 0, 0, 0)
        //     returndatacopy(0x00, 0x00, returndatasize()) // store runtimecode to memory
        //     return(0x00, returndatasize())
        // }
    }

    function parameters()
        external
        view
        returns (address factory, address token0, address token1, uint24 fee, int24 tickSpacing)
    {
        (factory, token0, token1, fee, tickSpacing) = IRamsesV3Factory(RamsesV3Factory).parameters();
    }

    /// @notice this function deploys a contract that contains the creation code of the CL Pool, to be used for Pool creations
    function _deployCreationCode() internal returns (address) {
        bytes memory createCreationCode =
            abi.encodePacked(hex"600d380380600d6000396000f3", type(RamsesV3Pool).creationCode);

        address _creationCodeLocation;
        assembly ("memory-safe") {
            _creationCodeLocation := create(0, add(createCreationCode, 0x20), mload(createCreationCode))
        }

        return _creationCodeLocation;

        // the assembly code in createCreationCode uses type(RamsesV3Pool).creationCode as the return value

        // PUSH1 0x0D //PRELOADER SIZE

        // CODESIZE
        // SUB
        // DUP1

        // PUSH1 0x0D //PRELOADER SIZE
        // PUSH1 0x00
        // CODECOPY

        // PUSH1 0x00
        // RETURN

        // it is equivalent to the yul code below

        // assembly {
        //     preloaderSize := 0x0D // size of the preloader bytecode
        //     creationCodeSize := sub(codesize(), preloaderSize)
        //     codecopy(0x00, preloaderSize, creationCodeSize) // puts the creation code in memory
        //     return(0x00, creationCodeSize)
        // }
    }

    function poolBytecode() external pure returns (bytes memory _bytecode) {
        return type(RamsesV3Pool).creationCode;
    }

    function poolRuntimeCode() external {
        /// @dev mock deploy a pool to get the runtime code after constructors are done
        address tempPool = address(new RamsesV3Pool());

        /// @dev return the runtime code in revert data
        uint256 codeSize;
        assembly ("memory-safe") {
            codeSize := extcodesize(tempPool)
            extcodecopy(tempPool, 0, 0, codeSize)
            revert(0, codeSize)
        }
    }
}
