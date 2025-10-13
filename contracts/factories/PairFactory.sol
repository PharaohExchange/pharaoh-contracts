// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IPairFactory} from "../interfaces/IPairFactory.sol";
import {Errors} from "contracts/libraries/Errors.sol";
import {IPair} from "./../interfaces/IPair.sol";
import {Pair} from "./../Pair.sol";
import {IAccessHub} from "contracts/interfaces/IAccessHub.sol";
contract PairFactory is IPairFactory {
    /// @inheritdoc IPairFactory
    bytes32 public immutable pairCodeHash;

    address public immutable feeRecipientFactory;

    /// @dev max swap fee set to 50% (required for Dynamic Fee token)
    uint256 public constant MAX_FEE = 500_000;
    uint256 public constant FEE_DENOM = 1_000_000;

    /// @inheritdoc IPairFactory
    address public voter;

    /// @inheritdoc IPairFactory
    address public treasury;

    IAccessHub public accessHub;

    uint256 public fee;
    uint256 public feeSplit;

    mapping(address token0 => mapping(address token1 => mapping(bool stable => address pair))) public getPair;
    address[] public allPairs;
    /// @dev simplified check if its a pair, given that `stable` flag might not be available in peripherals
    mapping(address pair => bool isPair) public isPair;

    /// @dev pair => fee
    mapping(address pair => uint256 fee) private _pairFee;

    /// @dev whether the pair has skim enabled or not
    mapping(address pair => bool skimEnabled) public skimEnabled;

    /// @dev if enabled, fee split to treasury if no gauge
    bool public feeSplitWhenNoGauge;

    constructor(IAccessHub _accessHub) {
        /// @dev default of 0.30%
        fee = 3000;
        emit SetFee(3000);
        accessHub = _accessHub;
        voter = address(accessHub.voter());
        treasury = accessHub.treasury();
        feeRecipientFactory = address(accessHub.feeRecipientFactory());
        pairCodeHash = keccak256(type(Pair).creationCode);

        /// @dev set feeSplitWhenNoGauge
        feeSplitWhenNoGauge = true;
        emit FeeSplitWhenNoGauge(msg.sender, true);

        /// @dev default of 5%
        feeSplit = 50_000;
        emit SetFeeSplit(50_000);
    }

    modifier onlyGovernanceOrVoter() {
        require(msg.sender == address(accessHub) || msg.sender == voter);
        _;
    }

    modifier onlyGovernance() {
        require(msg.sender == address(accessHub), Errors.NOT_AUTHORIZED(msg.sender));
        _;
    }

    /// @inheritdoc IPairFactory
    function allPairsLength() external view returns (uint256) {
        return allPairs.length;
    }

    /**
     * @inheritdoc IPairFactory
     * @dev for GLOBAL
     */
    function setFee(uint256 _fee) external onlyGovernanceOrVoter {
        /// @dev ensure it's not zero
        require(_fee != 0, Errors.ZERO_FEE());
        /// @dev ensure less than or equal to MAX_FEE
        require(_fee <= MAX_FEE, Errors.FEE_TOO_HIGH());
        /// @dev set the global fee
        fee = _fee;

        emit SetFee(_fee);
    }

    /**
     * @inheritdoc IPairFactory
     * @dev for INDIVIDUAL PAIRS
     */
    function setPairFee(address _pair, uint256 _fee) external onlyGovernanceOrVoter {
        /// @dev ensure less than or equal to MAX_FEE
        require(_fee <= MAX_FEE, Errors.FEE_TOO_HIGH());
        /// @dev if _fee is set to 0, fallback to default fee for the pair
        uint256 __fee = (_fee == 0 ? fee : _fee);
        /// @dev set to the new fee
        IPair(_pair).setFee(__fee);
        /// @dev store the fee
        _pairFee[_pair] = __fee;

        emit SetPairFee(_pair, _fee);
    }

    /// @inheritdoc IPairFactory
    function pairFee(address _pair) public view returns (uint256 feeForPair) {
        return _pairFee[_pair];
    }

    /// @inheritdoc IPairFactory
    function setTreasury(address _treasury) external onlyGovernance {
        treasury = _treasury;
        emit NewTreasury(msg.sender, _treasury);
    }

    /// @inheritdoc IPairFactory
    /// @notice allow feeSplit directly to treasury if (gauge) does not exist
    function setFeeSplitWhenNoGauge(bool status) external onlyGovernance {
        feeSplitWhenNoGauge = status;
        emit FeeSplitWhenNoGauge(msg.sender, status);
    }

    /// @inheritdoc IPairFactory
    /// @notice set the percent of fee growth to mint in BP, with 1m being 100%
    /// @dev gated to voter or AccessHub
    function setFeeSplit(uint256 _feeSplit) external onlyGovernanceOrVoter {
        /// @dev ensure feeSplit is within bounds
        require(_feeSplit <= FEE_DENOM, Errors.INVALID_FEE_SPLIT());
        /// @dev update the global feeSplit for newly created pairs
        feeSplit = _feeSplit;

        emit SetFeeSplit(_feeSplit);
    }

    /// @inheritdoc IPairFactory
    function setPairFeeSplit(address _pair, uint256 _feeSplit) external onlyGovernanceOrVoter {
        /// @dev ensure feeSplit is within bounds
        require(_feeSplit <= FEE_DENOM, Errors.INVALID_FEE_SPLIT());
        /// @dev set the feeSplit for the specific pair
        IPair(_pair).setFeeSplit(_feeSplit);

        emit SetPairFeeSplit(_pair, _feeSplit);
    }

    /// @inheritdoc IPairFactory
    function createPair(address tokenA, address tokenB, bool stable) external returns (address pair) {
        /// @dev ensure that tokenA and tokenB are not the same
        require(tokenA != tokenB, Errors.INVALID_ASSORTMENT());
        /// @dev calculate token0 and token1 of the pair by sorting the addresses
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        /// @dev require token is not the 0 address
        /// @dev we only check token0 because address(0) would be sorted first
        require(token0 != address(0), Errors.ZERO_ADDRESS());
        /// @dev ensure the pairing does not already exist
        require(getPair[token0][token1][stable] == address(0), Errors.PAIR_EXISTS());

        /// @dev pair creation logic
        bytes32 salt = keccak256(abi.encodePacked(token0, token1, stable));
        pair = address(new Pair{salt: salt}());

        /// @dev initialize the pair upon creation
        IPair(pair).initialize(token0, token1, stable);
        /// @dev should almost always default to the global fee
        IPair(pair).setFee(fee);
        /// @dev update the factory’s record so pairFee(_pair) returns the right value
        _pairFee[pair] = fee;

        /// @dev if we want an active fee split for gaugeless pairs
        if (feeSplitWhenNoGauge) {
            /// @dev set the fee recipient as the treasury
            IPair(pair).setFeeRecipient(treasury);
            /// @dev set the global fee split to the pair
            IPair(pair).setFeeSplit(feeSplit);
        }
        /// @dev populate mapping
        getPair[token0][token1][stable] = pair;
        /// @dev populate mapping in the reverse direction
        getPair[token1][token0][stable] = pair;
        /// @dev push to the allPairs set
        allPairs.push(pair);
        /// @dev set the pair status as true
        isPair[pair] = true;

        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    /// @inheritdoc IPairFactory
    /// @dev gated to Voter or AccessHub
    function setFeeRecipient(address _pair, address _feeRecipient) external {
        /// @dev only Voter or Access Hub can call
        require(msg.sender == voter || msg.sender == address(accessHub), Errors.NOT_AUTHORIZED(msg.sender));
        /// @dev set the fee receiving contract for a pair
        IPair(_pair).setFeeRecipient(_feeRecipient);

        emit SetFeeRecipient(_pair, _feeRecipient);
    }

    function setVoter(address _voter) external onlyGovernance {
        voter = _voter;
        emit SetVoter(_voter);
    }

    /// @inheritdoc IPairFactory
    /// @dev function restrict or enable skim functionality on legacy pairs
    function setSkimEnabled(address _pair, bool _status) external onlyGovernance {
        skimEnabled[_pair] = skimEnabled[_pair] != _status ? _status : skimEnabled[_pair];
        emit SkimStatus(_pair, _status);
    }
}
