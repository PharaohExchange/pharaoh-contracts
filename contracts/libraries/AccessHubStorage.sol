// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {
    AccessControlEnumerableUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {Errors} from "contracts/libraries/Errors.sol";
import {IXPhar} from "contracts/interfaces/IXPhar.sol";
import {IP33} from "contracts/interfaces/IP33.sol";

import {IRamsesV3Factory} from "contracts/CL/core/interfaces/IRamsesV3Factory.sol";
import {IRamsesV3Pool} from "contracts/CL/core/interfaces/IRamsesV3Pool.sol";
import {IGaugeV3} from "contracts/CL/gauge/interfaces/IGaugeV3.sol";
import {IFeeCollector} from "contracts/CL/gauge/interfaces/IFeeCollector.sol";
import {INonfungiblePositionManager} from "contracts/CL/periphery/interfaces/INonfungiblePositionManager.sol";

import {IPairFactory} from "contracts/interfaces/IPairFactory.sol";
import {IFeeRecipientFactory} from "contracts/interfaces/IFeeRecipientFactory.sol";

import {IVoter} from "contracts/interfaces/IVoter.sol";
import {IMinter} from "contracts/interfaces/IMinter.sol";
import {IVoteModule} from "contracts/interfaces/IVoteModule.sol";
import {IGaugeV3} from "contracts/CL/gauge/interfaces/IGaugeV3.sol";
import {IFeeDistributor} from "contracts/interfaces/IFeeDistributor.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

library AccessHubStorage {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @custom:storage-location erc7201:storage.AccessHub
    struct AccessHubState {
        /// @inheritdoc IAccessHub
        address timelock;
        /// @inheritdoc IAccessHub
        address treasury;
        /**
         * "nice-to-have" addresses for quickly finding contracts within the system
         */

        /// @inheritdoc IAccessHub
        address clGaugeFactory;
        /// @inheritdoc IAccessHub
        address gaugeFactory;
        /// @inheritdoc IAccessHub
        address feeDistributorFactory;
        /**
         * core contracts
         */

        /// @notice central voter contract
        IVoter voter;
        /// @notice weekly emissions minter
        IMinter minter;

        /// @notice xRam contract
        IXPhar xRam;
        /// @notice X33 contract
        IP33 x33;
        /// @notice CL V3 factory
        IRamsesV3Factory ramsesV3PoolFactory;
        /// @notice legacy pair factory
        IPairFactory poolFactory;
        /// @notice legacy fees holder contract
        IFeeRecipientFactory feeRecipientFactory;
        /// @notice fee collector contract
        IFeeCollector feeCollector;
        /// @notice voteModule contract
        IVoteModule voteModule;
        /// @notice NFPManager contract
        INonfungiblePositionManager nfpManager;
        EnumerableSet.AddressSet expansionPacks;
        EnumerableSet.AddressSet sybilBlacklist; // not used anymore as validation happens on RewardValidator
    }

    // keccak256(abi.encode(uint256(keccak256("storage.AccessHub")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant ACCESS_HUB_STORAGE_LOCATION =
        0xd3433e2ecf019e7839d3fa6d20b123561a6ea91df0afa4cf6f2c4f62a6985200;

    // keccak256("FUNCTION_NOT_FOUND_MAGIC_VALUE")
    bytes32 internal constant FUNCTION_NOT_FOUND_MAGIC_VALUE =
        0xa38b45c70495df5d1b49c0fdebe350e18f9fee4fe88a50a904eca9e5b46cca80;

    /// @dev Return state storage struct for reading and writing
    function getStorage() internal pure returns (AccessHubState storage $) {
        assembly {
            $.slot := ACCESS_HUB_STORAGE_LOCATION
        }
    }

    /// @dev Return state storage struct for reading and writing
    function getOriginalStorage() internal pure returns (AccessHubState storage $) {
        assembly {
            $.slot := 0
        }
    }

    //   AccessHubStorage.AccessHubState storage $ = AccessHubStorage.getStorage();
    //     IRamsesV3Factory ramsesV3PoolFactory = $.ramsesV3PoolFactory; 
    //     IPairFactory poolFactory = $.poolFactory;
    //     IFeeCollector feeCollector = $.feeCollector;
    //     IVoter voter = $.voter;
    // 	ILauncherPlugin launcherPlugin = $.launcherPlugin;
    // 	IVoteModule voteModule=$.voteModule;

    // 	IXPhar xRam = $.xRam;
}
