// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20Extended} from "./interfaces/IERC20Extended.sol";
import {UQ112x112} from "./libraries/UQ112x112.sol";
import {IPairCallee} from "./interfaces/IPairCallee.sol";
import {IPairFactory} from "./interfaces/IPairFactory.sol";
import {IPair} from "./interfaces/IPair.sol";
import {Errors} from "contracts/libraries/Errors.sol";

contract Pair is IPair, ERC20, ReentrancyGuard {
    using UQ112x112 for uint224;

    /// @dev Structure to capture time period obervations every 30 minutes, used for local oracles
    struct Observation {
        uint256 timestamp;
        uint256 reserve0Cumulative;
        uint256 reserve1Cumulative;
    }

    Observation[] public observations;

    uint256 internal _unlocked;

    /// @notice Capture oracle reading every 30 minutes
    uint256 constant PERIOD_SIZE = 1800;

    /// @notice min liquidity amount which is burned on creation
    uint256 public constant MINIMUM_LIQUIDITY = 10 ** 3;

    /// @notice legacy factory address
    address public immutable factory;
    /// @notice token0 in the pool
    address public token0;
    /// @notice token1 in the pool
    address public token1;
    /// @notice where the swap fees accrue to
    address public feeRecipient;

    /// @dev uses single storage slot, accessible via getReserves
    uint112 private reserve0;
    /// @dev uses single storage slot, accessible via getReserves
    uint112 private reserve1;
    /// @dev uses single storage slot, accessible via getReserves
    uint32 private blockTimestampLast;

    uint256 public reserve0CumulativeLast;
    uint256 public reserve1CumulativeLast;
    /// @dev reserve0 * reserve1, as of immediately after the most recent liquidity event
    uint256 public kLast;
    /// @dev the portion that goes to feeRecipient, rest goes to LPs. 100% of the fees goes to feeRecipient if it's set to 1m
    uint256 public feeSplit;
    uint256 public fee;

    uint256 internal decimals0;
    uint256 internal decimals1;
    /// @dev first MINIMUM_LIQUIDITY tokens are permanently locked
    uint256 internal constant MINIMUM_K = 10 ** 9;
    /// @dev 1m = 100%
    uint256 internal constant FEE_DENOM = 1_000_000;
    /// @notice whether the pool uses the xy(x^2 + y^2) = xy^3 + x^3y swap curve
    bool public stable;

    string internal _name;
    string internal _symbol;

    modifier onlyFactory() {
        /// @dev gate to the PairFactory
        require(msg.sender == factory, Errors.NOT_AUTHORIZED(msg.sender));
        _;
    }

    constructor() ERC20("", "") {
        /// @dev initialize the factory address
        factory = msg.sender;
    }

    /// @inheritdoc IPair
    function initialize(address _token0, address _token1, bool _stable) external onlyFactory {
        token0 = _token0;
        token1 = _token1;

        string memory __name;
        string memory __symbol;
        stable = _stable;
        if (_stable) {
            __name = string(
                string.concat(
                    "Pharaoh StableSwap - ",
                    IERC20Extended(token0).symbol(),
                    "/",
                    IERC20Extended(token1).symbol()
                )
            );
            __symbol = string(
                string.concat("Stable - ", IERC20Extended(token0).symbol(), "/", IERC20Extended(token1).symbol())
            );
        } else {
            __name = string(
                string.concat(
                    "Pharaoh Volatile - ",
                    IERC20Extended(token0).symbol(),
                    "/",
                    IERC20Extended(token1).symbol()
                )
            );
            __symbol = string(
                string.concat("Volatile - ", IERC20Extended(token0).symbol(), "/", IERC20Extended(token1).symbol())
            );
        }

        _name = __name;
        _symbol = __symbol;

        observations.push(Observation(block.timestamp, 0, 0));

        decimals0 = 10 ** IERC20Extended(token0).decimals();
        decimals1 = 10 ** IERC20Extended(token1).decimals();
    }
    /// @inheritdoc IPair

    function getReserves() public view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

    function _safeTransfer(address token, address to, uint256 value) private {
        require(token.code.length > 0);
        (bool success, bytes memory data) = token.call(abi.encodeCall(IERC20Extended.transfer, (to, value)));
        if (!(success && (data.length == 0 || abi.decode(data, (bool))))) {
            revert Errors.SAFE_TRANSFER_FAILED();
        }
    }

    /// @dev update reserves and, on the first call per block, reserve accumulators
    function _update(uint256 balance0, uint256 balance1, uint112 _reserve0, uint112 _reserve1) private {
        /// @dev ensure no overflow
        require(balance0 <= type(uint112).max && balance1 <= type(uint112).max, Errors.OVERFLOW());
        /// @dev store blockstamp
        uint256 blockTimestamp = block.timestamp;
        /// @dev declare
        uint256 timeElapsed;

        /// @dev overflow is desired
        unchecked {
            /// @dev time elapsed since the last update
            timeElapsed = blockTimestamp - uint256(blockTimestampLast);
            /// @dev if timeElapsed is gt 0 and the reserves are not 0
            if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
                /// @dev update the cumulatives
                reserve0CumulativeLast += _reserve0 * timeElapsed;
                reserve1CumulativeLast += _reserve1 * timeElapsed;
            }
        }
        /// @dev fetch the last observation
        Observation memory _point = lastObservation();
        /// @dev compare the last observation with current timestamp, if greater than 30 minutes, record a new event
        timeElapsed = blockTimestamp - _point.timestamp;
        /// @dev if > the PERIOD_SIZE (usually 30m twap)
        if (timeElapsed > PERIOD_SIZE) {
            observations.push(Observation(blockTimestamp, reserve0CumulativeLast, reserve1CumulativeLast));
        }

        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimestampLast = uint32(blockTimestamp);
        emit Sync(reserve0, reserve1);
    }

    /// @dev if fee is on, mint liquidity up to the entire growth in sqrt(k)
    function _mintFee(uint112 _reserve0, uint112 _reserve1) private returns (bool feeOn) {
        /// @dev gas savings
        address _feeRecipient = feeRecipient;
        /// @dev gas savings
        uint256 _kLast = kLast;
        /// @dev we define fee being on as the existence of the fee recipient
        feeOn = _feeRecipient != address(0);
        /// @dev if there are any fees not going to LP providers
        if (feeOn) {
            /// @dev portion of fees that go to feeRecipient
            uint256 _feeSplit = feeSplit;
            /// @dev if the reserve calculation is not 0
            if (_kLast != 0) {
                /// @dev if a stableswap/correlated pair with curve: xy(x^2y + y^2x) >= k
                if (stable) {
                    /// @dev fetch current k value
                    uint256 k = _k(_reserve0, _reserve1);
                    /// @dev if k is greater than the _kLast variable
                    if (k > _kLast) {
                        uint256 fourthRoot_e18 = Math.sqrt(Math.mulDiv(Math.sqrt(_kLast), 1e36, Math.sqrt(k)));

                        uint256 numerator = _feeSplit * (1e18 - fourthRoot_e18) * 1e18;
                        uint256 denominator = ((FEE_DENOM * 1e18) - (_feeSplit * (1e18 - fourthRoot_e18)));

                        /// @dev new liquidity to be minted
                        uint256 feeAsLiquidity = (totalSupply() * numerator) / denominator / 1e18;

                        if (feeAsLiquidity > 0) {
                            _mint(_feeRecipient, feeAsLiquidity);
                        }
                    }
                }
                /// @dev if !stable
                else {
                    uint256 rootK = Math.sqrt(_k(uint256(_reserve0), uint256(_reserve1)));
                    uint256 rootKLast = Math.sqrt(_kLast);
                    if (rootK > rootKLast) {
                        /// @dev calculate fee amounts to send
                        uint256 diffK = rootK - rootKLast;
                        uint256 dueToProtocol = (diffK * _feeSplit) / FEE_DENOM;
                        uint256 dueToLp = rootKLast + diffK - dueToProtocol;

                        /// @dev new liquidity to be minted
                        /// @dev n = s*P/d
                        uint256 feeAsLiquidity = (totalSupply() * dueToProtocol) / dueToLp;

                        if (feeAsLiquidity > 0) {
                            _mint(_feeRecipient, feeAsLiquidity);
                        }
                    }
                }
            }
        }
        /// @dev if !feeOn
        else if (_kLast != 0) {
            /// @dev update kLast to reflect reserves
            kLast = _k(reserve0, reserve1);
        }
    }
    /// @inheritdoc IPair
    /// @dev this low-level function should be called from a contract which performs important safety checks

    function mint(address to) external nonReentrant returns (uint256 liquidity) {
        /// @dev gas savings
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        uint256 balance0 = IERC20Extended(token0).balanceOf(address(this));
        uint256 balance1 = IERC20Extended(token1).balanceOf(address(this));
        uint256 amount0 = balance0 - _reserve0;
        uint256 amount1 = balance1 - _reserve1;

        bool feeOn = _mintFee(_reserve0, _reserve1);
        /// @dev gas savings, must be defined here since totalSupply can update in _mintFee
        uint256 _totalSupply = totalSupply();
        if (_totalSupply == 0) {
            liquidity = Math.sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
            /// @dev permanently lock the first MINIMUM_LIQUIDITY tokens
            _mint(address(0xdead), MINIMUM_LIQUIDITY);
            if (stable) {
                require(_k(amount0, amount1) >= MINIMUM_K, Errors.K());
                require(((amount0 * 1e18) / decimals0 == (amount1 * 1e18) / decimals1), Errors.UNSTABLE_RATIO());
            }
        } else {
            liquidity = Math.min((amount0 * _totalSupply) / _reserve0, (amount1 * _totalSupply) / _reserve1);
        }
        require(liquidity != 0, Errors.INSUFFICIENT_LIQUIDITY_MINTED());
        _mint(to, liquidity);

        _update(balance0, balance1, _reserve0, _reserve1);
        /// @dev reserve0 and reserve1 are up-to-date
        if (feeOn) kLast = _k(uint256(reserve0), uint256(reserve1));
        emit Mint(msg.sender, amount0, amount1);
    }
    /// @inheritdoc IPair
    /// @dev this low-level function should be called from a contract which performs important safety checks

    function burn(address to) external nonReentrant returns (uint256 amount0, uint256 amount1) {
        /// @dev gas savings
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        /// @dev gas savings
        address _token0 = token0;
        /// @dev gas savings
        address _token1 = token1;
        uint256 balance0 = IERC20Extended(_token0).balanceOf(address(this));
        uint256 balance1 = IERC20Extended(_token1).balanceOf(address(this));
        /// @dev fetch the balance of the liquidity of the Pair
        uint256 liquidity = balanceOf(address(this));
        /// @dev attempt to mint fees and calculate if feeOn is active
        bool feeOn = _mintFee(_reserve0, _reserve1);
        /// @dev gas savings, must be defined here since totalSupply can update in _mintFee
        uint256 _totalSupply = totalSupply();
        /// @dev using balances ensures pro-rata distribution
        amount0 = (liquidity * balance0) / _totalSupply;
        /// @dev using balances ensures pro-rata distribution
        amount1 = (liquidity * balance1) / _totalSupply;
        /// @dev require the amounts are not zero, else it's insufficient liquidity burned and revert
        require(amount0 != 0 && amount1 != 0, Errors.INSUFFICIENT_LIQUIDITY_BURNED());
        /// @dev burn the liquidity tokens
        _burn(address(this), liquidity);
        /// @dev safe transfer the two underlying tokens (incase of tax tokens etc)
        _safeTransfer(_token0, to, amount0);
        _safeTransfer(_token1, to, amount1);
        /// @dev fetch updated balances
        balance0 = IERC20Extended(_token0).balanceOf(address(this));
        balance1 = IERC20Extended(_token1).balanceOf(address(this));
        /// @dev update with the new balances
        _update(balance0, balance1, _reserve0, _reserve1);
        /// @dev reserve0 and reserve1 are up-to-date
        if (feeOn) kLast = _k(reserve0, reserve1);
        emit Burn(msg.sender, amount0, amount1, to);
    }
    /// @inheritdoc IPair
    /// @dev this low-level function should be called from a contract which performs important safety checks

    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external nonReentrant {
        /// @dev require at least one is not 0, else revert for Insufficient Output Amount
        require(amount0Out != 0 || amount1Out != 0, Errors.INSUFFICIENT_OUTPUT_AMOUNT());

        /// @dev gas savings
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        /// @dev ensure there is enough liquidity for the swap
        require(amount0Out < _reserve0 && amount1Out < _reserve1, Errors.INSUFFICIENT_LIQUIDITY());

        uint256 amount0In;
        uint256 amount1In;
        uint256 balance0;
        uint256 balance1;
        /// @dev stack-too-deep
        {
            /// @dev gas savings
            address _token0 = token0;
            address _token1 = token1;

            require(to != _token0 && to != _token1, Errors.INVALID_TRANSFER());
            /// @dev optimistically transfer tokens
            if (amount0Out > 0) _safeTransfer(_token0, to, amount0Out);
            /// @dev optimistically transfer tokens
            if (amount1Out > 0) _safeTransfer(_token1, to, amount1Out);
            if (data.length > 0) {
                IPairCallee(to).hook(msg.sender, amount0Out, amount1Out, data);
            }
            balance0 = IERC20Extended(_token0).balanceOf(address(this));
            balance1 = IERC20Extended(_token1).balanceOf(address(this));

            unchecked {
                amount0In = balance0 > _reserve0 - amount0Out ? balance0 - (_reserve0 - amount0Out) : 0;
                amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;
            }
            require(amount0In != 0 || amount1In != 0, Errors.INSUFFICIENT_INPUT_AMOUNT());

            /// @dev FEE_DENOM as the denominator invariant for calculating swap fees
            uint256 balance0Adjusted = balance0 - ((amount0In * fee) / FEE_DENOM);
            uint256 balance1Adjusted = balance1 - ((amount1In * fee) / FEE_DENOM);

            require(_k(balance0Adjusted, balance1Adjusted) >= _k(uint256(_reserve0), uint256(_reserve1)), Errors.K());
        }

        _update(balance0, balance1, _reserve0, _reserve1);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    /// @inheritdoc IPair
    function skim(address to) external nonReentrant {
        /// @dev if skim disabled, revert
        /// @dev by default it is disabled as it uses a mapping in the pair factory contract
        require((IPairFactory(factory).skimEnabled(address(this))), Errors.SKIM_DISABLED());
        /// @dev gas savings
        address _token0 = token0;
        /// @dev gas savings
        address _token1 = token1;
        _safeTransfer(_token0, to, IERC20Extended(_token0).balanceOf(address(this)) - reserve0);
        _safeTransfer(_token1, to, IERC20Extended(_token1).balanceOf(address(this)) - reserve1);
    }

    /// @inheritdoc IPair
    function sync() external nonReentrant {
        /// @dev update the reserves to match balances
        _update(
            IERC20Extended(token0).balanceOf(address(this)),
            IERC20Extended(token1).balanceOf(address(this)),
            reserve0,
            reserve1
        );
    }
    /// @inheritdoc IPair

    function setFeeRecipient(address _feeRecipient) external onlyFactory {
        feeRecipient = _feeRecipient;
    }
    /// @inheritdoc IPair

    function setFeeSplit(uint256 _feeSplit) external onlyFactory {
        feeSplit = _feeSplit;
    }
    /// @inheritdoc IPair

    function setFee(uint256 _fee) external onlyFactory {
        fee = _fee;
    }
    /// @inheritdoc IPair

    function mintFee() external nonReentrant {
        /// @dev fetch the current public reserves
        uint112 _reserve0 = reserve0;
        uint112 _reserve1 = reserve1;
        /// @dev mint the accumulated fees
        bool feeOn = _mintFee(_reserve0, _reserve1);
        /// @dev if minting was successful
        if (feeOn) kLast = _k(uint256(_reserve0), uint256(_reserve1));
    }

    function _k(uint256 x, uint256 y) internal view returns (uint256) {
        if (stable) {
            uint256 _x = (x * 10 ** 18) / decimals0;
            uint256 _y = (y * 10 ** 18) / decimals1;
            uint256 _a = (_x * _y) / 10 ** 18;
            uint256 _b = ((_x * _x) / 10 ** 18 + (_y * _y) / 10 ** 18);
            /// @dev x3y+y3x >= k
            return (_a * _b) / 10 ** 18;
        } else {
            /// @dev xy >= k
            return x * y;
        }
    }

    function _f(uint256 x0, uint256 y) internal pure returns (uint256) {
        return (x0 * ((((y * y) / 1e18) * y) / 1e18)) / 1e18 + (((((x0 * x0) / 1e18) * x0) / 1e18) * y) / 1e18;
    }

    function _d(uint256 x0, uint256 y) internal pure returns (uint256) {
        return (3 * x0 * ((y * y) / 1e18)) / 1e18 + ((((x0 * x0) / 1e18) * x0) / 1e18);
    }

    function _get_y(uint256 x0, uint256 xy, uint256 y) internal pure returns (uint256) {
        for (uint256 i = 0; i < 255; ++i) {
            uint256 y_prev = y;
            uint256 k = _f(x0, y);
            if (k < xy) {
                uint256 dy = ((xy - k) * 1e18) / _d(x0, y);
                y = y + dy;
            } else {
                uint256 dy = ((k - xy) * 1e18) / _d(x0, y);
                y = y - dy;
            }
            if (y > y_prev) {
                if (y - y_prev <= 1) {
                    return y;
                }
            } else {
                if (y_prev - y <= 1) {
                    return y;
                }
            }
        }
        return y;
    }
    /// @inheritdoc IPair

    function getAmountOut(uint256 amountIn, address tokenIn) external view returns (uint256) {
        (uint256 _reserve0, uint256 _reserve1) = (reserve0, reserve1);
        /// @dev remove fee from amount received
        amountIn -= (amountIn * fee) / FEE_DENOM;

        return _getAmountOut(amountIn, tokenIn, _reserve0, _reserve1) - 1;
    }

    function _getAmountOut(uint256 amountIn, address tokenIn, uint256 _reserve0, uint256 _reserve1)
        internal
        view
        returns (uint256)
    {
        if (stable) {
            uint256 xy = _k(_reserve0, _reserve1);
            _reserve0 = (_reserve0 * 1e18) / decimals0;
            _reserve1 = (_reserve1 * 1e18) / decimals1;
            (uint256 reserveA, uint256 reserveB) = tokenIn == token0 ? (_reserve0, _reserve1) : (_reserve1, _reserve0);
            amountIn = tokenIn == token0 ? (amountIn * 1e18) / decimals0 : (amountIn * 1e18) / decimals1;
            uint256 y = reserveB - _get_y(amountIn + reserveA, xy, reserveB);
            return (y * (tokenIn == token0 ? decimals1 : decimals0)) / 1e18;
        } else {
            (uint256 reserveA, uint256 reserveB) = tokenIn == token0 ? (_reserve0, _reserve1) : (_reserve1, _reserve0);
            return (amountIn * reserveB) / (reserveA + amountIn);
        }
    }

    function metadata()
        external
        view
        returns (
            uint256 _decimals0,
            uint256 _decimals1,
            uint256 _reserve0,
            uint256 _reserve1,
            bool _stable,
            address _token0,
            address _token1
        )
    {
        return (decimals0, decimals1, reserve0, reserve1, stable, token0, token1);
    }

    /// @dev override the standard inherited name
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /// @dev override the inherited name
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function observationLength() external view returns (uint256) {
        return observations.length;
    }

    function lastObservation() public view returns (Observation memory) {
        return observations[observations.length - 1];
    }

    /// @dev produces the cumulative price using counterfactuals to save gas and avoid a call to sync.
    function currentCumulativePrices()
        public
        view
        returns (uint256 reserve0Cumulative, uint256 reserve1Cumulative, uint256 blockTimestamp)
    {
        blockTimestamp = block.timestamp;
        reserve0Cumulative = reserve0CumulativeLast;
        reserve1Cumulative = reserve1CumulativeLast;

        /// @dev if time has elapsed since the last update on the pair, mock the accumulated price values
        (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) = getReserves();
        if (_blockTimestampLast != uint32(blockTimestamp)) {
            /// @dev subtraction overflow is desired
            uint256 timeElapsed = blockTimestamp - uint256(_blockTimestampLast);
            reserve0Cumulative += _reserve0 * timeElapsed;
            reserve1Cumulative += _reserve1 * timeElapsed;
        }
    }

    /// @dev gives the current twap price measured from amountIn * tokenIn gives amountOut
    function current(address tokenIn, uint256 amountIn) external view returns (uint256 amountOut) {
        Observation memory _observation = lastObservation();
        (uint256 reserve0Cumulative, uint256 reserve1Cumulative,) = currentCumulativePrices();
        if (block.timestamp == _observation.timestamp) {
            _observation = observations[observations.length - 2];
        }

        uint256 timeElapsed = block.timestamp - _observation.timestamp;
        uint256 _reserve0 = (reserve0Cumulative - _observation.reserve0Cumulative) / timeElapsed;
        uint256 _reserve1 = (reserve1Cumulative - _observation.reserve1Cumulative) / timeElapsed;
        amountOut = _getAmountOut(amountIn, tokenIn, _reserve0, _reserve1);
    }

    /// @dev as per `current`, however allows user configured granularity, up to the full window size
    function quote(address tokenIn, uint256 amountIn, uint256 granularity) external view returns (uint256 amountOut) {
        uint256[] memory _prices = sample(tokenIn, amountIn, granularity, 1);
        uint256 priceAverageCumulative;
        for (uint256 i = 0; i < _prices.length; ++i) {
            priceAverageCumulative += _prices[i];
        }
        return priceAverageCumulative / granularity;
    }

    /// @dev returns a memory set of twap prices
    function prices(address tokenIn, uint256 amountIn, uint256 points) external view returns (uint256[] memory) {
        return sample(tokenIn, amountIn, points, 1);
    }

    function sample(address tokenIn, uint256 amountIn, uint256 points, uint256 window)
        public
        view
        returns (uint256[] memory)
    {
        uint256[] memory _prices = new uint256[](points);

        uint256 length = observations.length - 1;
        uint256 i = length - (points * window);
        uint256 nextIndex = 0;
        uint256 index = 0;

        for (; i < length; i += window) {
            nextIndex = i + window;
            uint256 timeElapsed = observations[nextIndex].timestamp - observations[i].timestamp;
            uint256 _reserve0 =
                (observations[nextIndex].reserve0Cumulative - observations[i].reserve0Cumulative) / timeElapsed;
            uint256 _reserve1 =
                (observations[nextIndex].reserve1Cumulative - observations[i].reserve1Cumulative) / timeElapsed;
            _prices[index] = _getAmountOut(amountIn, tokenIn, _reserve0, _reserve1);
            /// @dev index < length; length cannot overflow
            unchecked {
                index = index + 1;
            }
        }
        return _prices;
    }
}
