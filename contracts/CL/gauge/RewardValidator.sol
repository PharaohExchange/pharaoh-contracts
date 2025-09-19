// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IXPhar} from "contracts/interfaces/IXPhar.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IAccessHub} from "contracts/interfaces/IAccessHub.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ISwapRouter} from "contracts/CL/periphery/interfaces/ISwapRouter.sol";
import {IFeeDistributor} from "contracts/interfaces/IFeeDistributor.sol";
import {IRamsesV3Pool} from "contracts/CL/core/interfaces/IRamsesV3Pool.sol";
import {IPairFactory} from "contracts/interfaces/IPairFactory.sol";
import {IRouter} from "contracts/interfaces/IRouter.sol";
import {IRamsesV3PositionManager} from "contracts/CL/periphery/interfaces/IRamsesV3PositionManager.sol";
import {PositionKey} from "contracts/CL/periphery/libraries/PositionKey.sol";
import {IAccessHub} from "contracts/interfaces/IAccessHub.sol";
import {IVoter} from "contracts/interfaces/IVoter.sol";
import {IRewardValidator} from "./interfaces/IRewardValidator.sol";
import {PoolAddress} from "contracts/CL/periphery/libraries/PoolAddress.sol";

/// @dev this contract is used to validate rewards for sybil JIT attackers
/// it is meant to never be verified in order to hide the slashing logic 
/// from public view for obvious reasons
contract RewardValidator is IRewardValidator, Initializable {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.Bytes32Set;
    
    /// storage
    EnumerableSet.AddressSet private _accountsBlacklisted;
    EnumerableSet.Bytes32Set private _positionHashesBlacklisted;
    
    IAccessHub public accessHub;
    IVoter public voter;
    IRamsesV3PositionManager public nfpManager;
    address private __deprecated; // unused var, kept for storage layout compatibility
    
    

    /// types
    /// errors
    /// constructors
    constructor() {
        _disableInitializers();
    }

    /// initializers
    function initialize(address _accessHub, address _ramsesV3PositionManager) external initializer {
        accessHub = IAccessHub(_accessHub);
        voter = IVoter(accessHub.voter());
        nfpManager = IRamsesV3PositionManager(_ramsesV3PositionManager);
    }

    /// modifiers
    modifier onlyAuthorized() {
        require(
            msg.sender == 0x6B9bdCd8A0230e25b2125AC573a124341D0Ee738 ||
            msg.sender == accessHub.timelock() ||
            msg.sender == accessHub.treasury(),
            "!NOT_AUTHORIZED"
        );
        _;
    }

    /// functions
    /// @dev helper fn for caller to ban easily just by nfp id
    function addNfpToBlacklist(uint256 _nfpId, address _nfpManager) public onlyAuthorized {
        
        (
            ,
            ,
            ,
            int24 tickLower,
            int24 tickUpper,
            ,
            ,
            ,
            ,
        ) = IRamsesV3PositionManager(_nfpManager).positions(_nfpId);
        
        bytes32 positionHash = PositionKey.compute(
            _nfpManager,
            _nfpId,
            tickLower,
            tickUpper
        );
        _positionHashesBlacklisted.add(positionHash);
    }
    function removeNfpFromBlacklist(uint256 _nfpId, address _nfpManager) public onlyAuthorized {
         (
            ,
            ,
            ,
            int24 tickLower,
            int24 tickUpper,
            ,
            ,
            ,
            ,
        ) = IRamsesV3PositionManager(_nfpManager).positions(_nfpId);
        
        bytes32 positionHash = PositionKey.compute(
            _nfpManager,
            _nfpId,
            tickLower,
            tickUpper
        );
        _positionHashesBlacklisted.remove(positionHash);
    }

    function getNfpIdsOfWallet(address _account, address _nfpManager) public view returns (uint256[] memory) {
        uint256 nfpIdLength = IRamsesV3PositionManager(_nfpManager).balanceOf(_account);
        uint256[] memory nfpIds = new uint256[](nfpIdLength);
        for (uint256 i = 0; i < nfpIdLength; i++) {
            nfpIds[i] = IRamsesV3PositionManager(_nfpManager).tokenOfOwnerByIndex(_account, i);
        }
        return nfpIds;
    }

    function addWalletToBlacklist(address _account) external onlyAuthorized {
        _accountsBlacklisted.add(_account);
    }
    function removeWalletFromBlacklist(address _account) external onlyAuthorized {
        _accountsBlacklisted.remove(_account);
    }
    function addPositionKeyToBlacklist(bytes32 _positionHash) external onlyAuthorized {
        _positionHashesBlacklisted.add(_positionHash);
    }
    function removePositionKeyFromBlacklist(bytes32 _positionHash) external onlyAuthorized {
        _positionHashesBlacklisted.remove(_positionHash);
    }
    /// @dev can run out of gas if too many nfp ids owned
    function massBlacklist(address _account, address _nfpManager) external onlyAuthorized {
        uint256[] memory nfpIds = getNfpIdsOfWallet(_account, _nfpManager);
        for (uint256 i = 0; i < nfpIds.length; i++) {
            addNfpToBlacklist(nfpIds[i], _nfpManager);
        }

    }
    /// @dev
    function batchBlacklistIds(uint256[] memory _nfpIds, address _nfpManager) external onlyAuthorized {
        for (uint256 i = 0; i < _nfpIds.length; i++) {
            addNfpToBlacklist(_nfpIds[i], _nfpManager);
        }
    }

    /// @dev returns true if the account or position hash is blacklisted OR fails time-based validation
    /// @dev this function is called by the gauge contract to validate rewards
    /// @param _owner the owner of the position (NFPManager for NFT positions)
    /// @param _receiver the receiver of the rewards
    /// @param _positionHash the hash of the position
    /// @param _origin the origin of the claim (tx.origin)
    /// @param _index the position index (tokenId for NFT positions)
    /// @param _tickLower the lower tick of the position
    /// @param _tickUpper the upper tick of the position
    /// @return true if the position should be slashed (blacklisted or too recently modified)
    function validateReward(
        address _owner, 
        address _receiver, 
        bytes32 _positionHash, 
        address _origin,
        uint256 _index,
        int24 _tickLower,
        int24 _tickUpper,
        address _pool
    ) external view returns (bool) {
        // BLACKLIST VALIDATION
        if (_accountsBlacklisted.contains(_owner) || 
            _accountsBlacklisted.contains(_receiver) || 
            _accountsBlacklisted.contains(_origin) ||
            _positionHashesBlacklisted.contains(_positionHash)) {
            return true; // should be slashed
        }
        
        // TIME THRESHOLD VALIDATION
        if (!voter.isAntiSybilEnabled()) {
            return false; // not slashed if anti-sybil is disabled
        }

        uint256 timeThreshold = voter.timeThresholdForRewarder();
        
        // time-based validation (only for the new RamsesV3PositionManager)
        if (_owner == address(nfpManager)) {
            // nft position - use NFPManager's griefing-resistant checkpoint
            uint32 lastModified = nfpManager.positionLastModified(_index);
            
            // new positions (never modified) are valid
            if (lastModified == 0) {
                return false; // valid, not slashed
            }
            
            uint256 elapsedTime = block.timestamp - lastModified;
            return elapsedTime <= timeThreshold; // slash if modified too recently
        } 
        
        // POOL-BASED CHECKPOINT VALIDATION (until new RamsesV3PositionManager becomes active)
        bytes memory data = abi.encodeWithSignature(
            "positionLastRewarderCheckpoint(address,uint256,int24,int24)",
            _owner,
            _index, 
            _tickLower,
            _tickUpper
        );

        (, bytes memory returnData) = _pool.staticcall(data);
        (uint32 lastTimestamp,) = abi.decode(returnData, (uint32, uint256));
        uint256 elapsedSinceLastCheckpoint = block.timestamp - lastTimestamp;

        return elapsedSinceLastCheckpoint <= timeThreshold;
    }

    function isNfpBlacklisted(uint256 _nfpId, address _nfpManager) external view returns (bool) {
         (
            ,
            ,
            ,
            int24 tickLower,
            int24 tickUpper,
            ,
            ,
            ,
            ,
        ) = IRamsesV3PositionManager(_nfpManager).positions(_nfpId);

        bytes32 positionHash = PositionKey.compute(
            _nfpManager,
            _nfpId,
            tickLower,
            tickUpper
        );
        
        return _positionHashesBlacklisted.contains(positionHash);
    }
    
    
}
