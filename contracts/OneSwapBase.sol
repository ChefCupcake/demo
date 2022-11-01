// SPDX-License-Identifier: MIT
pragma solidity ^0.5.0;

import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol';
import './interface/IStableSwap.sol';
import './interface/IPancakeswapV2Factory.sol';
import './IOneSwap.sol';
import './interface/IWETH.sol';
import './UniversalERC20.sol';

contract IOneSwapView is IOneSwapConsts {
    function getExpectedReturn(
        IERC20 srcToken,
        IERC20 dstToken,
        uint256 amount,
        uint256 parts,
        uint256 flags // See constants in IOneSwap.sol
    )
        public
        view
        returns (
            uint256 returnAmount,
            uint256[] memory distribution
        );

    function getExpectedReturnWithGas(
        IERC20 srcToken,
        IERC20 dstToken,
        uint256 amount,
        uint256 parts,
        uint256 flags, // See constants in IOneSwap.sol
        uint256 dstTokenEthPriceTimesGasPrice
    )
        public
        view
        returns (
            uint256 returnAmount,
            uint256 estimateGasAmount,
            uint256[] memory distribution
        );
}

library DisableFlags {
    function check(uint256 flags, uint256 flag) internal pure returns (bool) {
        return (flags & flag) != 0;
    }
}

contract OneSwapRoot is IOneSwapView {
    using SafeMath for uint256;
    using DisableFlags for uint256;

    using UniversalERC20 for IERC20;
    using UniversalERC20 for IWETH;
    using PancakeswapV2ExchangeLib for IPancakeswapV2Exchange;

    uint256 constant internal DEXES_COUNT = 2;
    IERC20 constant internal ETH_ADDRESS = IERC20(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
    IERC20 constant internal ZERO_ADDRESS = IERC20(0);

    IWETH constant internal weth = IWETH(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IERC20 constant internal busd = IERC20(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);
    IERC20 constant internal hay = IERC20(0x0782b6d8c4551B9760e74c0545a9bCD90bdc41E5);

    IStableSwap constant internal stableswapHAY = IStableSwap(0x49079D07ef47449aF808A4f36c2a8dEC975594eC);
    IPancakeswapV2Factory constant internal pancakeswapV2 = IPancakeswapV2Factory(0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73);
    IStableSwapCalculator constant internal stableswapCalculator = IStableSwapCalculator(0x4b1bFb6f5E2B10770F08e2496E8d0CdB2e682798);

    int256 internal constant VERY_NEGATIVE_VALUE = -1e72;

    function _findBestDistribution(
        uint256 s,                // parts
        int256[][] memory amounts // exchangesReturns
    )
        internal
        pure
        returns (
            int256 returnAmount,
            uint256[] memory distribution
        )
    {
        uint256 n = amounts.length;

        int256[][] memory answer = new int256[][](n); // int[n][s+1]
        uint256[][] memory parent = new uint256[][](n); // int[n][s+1]

        for (uint i = 0; i < n; i++) {
            answer[i] = new int256[](s + 1);
            parent[i] = new uint256[](s + 1);
        }

        for (uint j = 0; j <= s; j++) {
            answer[0][j] = amounts[0][j];
            for (uint i = 1; i < n; i++) {
                answer[i][j] = -1e72;
            }
            parent[0][j] = 0;
        }

        for (uint i = 1; i < n; i++) {
            for (uint j = 0; j <= s; j++) {
                answer[i][j] = answer[i - 1][j];
                parent[i][j] = j;

                for (uint k = 1; k <= j; k++) {
                    if (answer[i - 1][j - k] + amounts[i][k] > answer[i][j]) {
                        answer[i][j] = answer[i - 1][j - k] + amounts[i][k];
                        parent[i][j] = j - k;
                    }
                }
            }
        }

        distribution = new uint256[](DEXES_COUNT);

        uint256 partsLeft = s;
        for (uint curExchange = n - 1; partsLeft > 0; curExchange--) {
            distribution[curExchange] = partsLeft - parent[curExchange][partsLeft];
            partsLeft = parent[curExchange][partsLeft];
        }

        returnAmount = (answer[n - 1][s] == VERY_NEGATIVE_VALUE) ? 0 : answer[n - 1][s];
    }

    function _linearInterpolation(
        uint256 value,
        uint256 parts
    ) internal pure returns (uint256[] memory rets) {
        rets = new uint256[](parts);
        for (uint i = 0; i < parts; i++) {
            rets[i] = value.mul(i + 1).div(parts);
        }
    }

    function _tokensEqual(IERC20 tokenA, IERC20 tokenB) internal pure returns (bool) {
        return ((tokenA.isETH() && tokenB.isETH()) || tokenA == tokenB);
    }
}

contract OneSwapViewWrapBase is IOneSwapView, OneSwapRoot {
    function getExpectedReturn(
        IERC20 srcToken,
        IERC20 dstToken,
        uint256 amount,
        uint256 parts,
        uint256 flags // See constants in IOneSwap.sol
    )
        public
        view
        returns (
            uint256 returnAmount,
            uint256[] memory distribution
        )
    {
        (returnAmount, , distribution) = this.getExpectedReturnWithGas(
            srcToken,
            dstToken,
            amount,
            parts,
            flags,
            0
        );
    }

    function getExpectedReturnWithGas(
        IERC20 srcToken,
        IERC20 dstToken,
        uint256 amount,
        uint256 parts,
        uint256 flags,
        uint256 dstTokenEthPriceTimesGasPrice
    )
        public
        view
        returns (
            uint256 returnAmount,
            uint256 estimateGasAmount,
            uint256[] memory distribution
        )
    {
        return _getExpectedReturnRespectingGasFloor(
            srcToken,
            dstToken,
            amount,
            parts,
            flags,
            dstTokenEthPriceTimesGasPrice
        );
    }

    function _getExpectedReturnRespectingGasFloor(
        IERC20 srcToken,
        IERC20 dstToken,
        uint256 amount,
        uint256 parts,
        uint256 flags, // See constants in IOneSwap.sol
        uint256 dstTokenEthPriceTimesGasPrice
    )
        internal
        view
        returns (
            uint256 returnAmount,
            uint256 estimateGasAmount,
            uint256[] memory distribution
        );
}

contract OneSwapView is IOneSwapView, OneSwapRoot {
    function getExpectedReturn(
        IERC20 srcToken,
        IERC20 dstToken,
        uint256 amount,
        uint256 parts,
        uint256 flags // See constants in IOneSwap.sol
    )
        public
        view
        returns (
            uint256 returnAmount,
            uint256[] memory distribution
        )
    {
        (returnAmount, , distribution) = getExpectedReturnWithGas(
            srcToken,
            dstToken,
            amount,
            parts,
            flags,
            0
        );
    }

    function getExpectedReturnWithGas(
        IERC20 srcToken,
        IERC20 dstToken,
        uint256 amount,
        uint256 parts,
        uint256 flags, // See constants in IOneSwap.sol
        uint256 dstTokenEthPriceTimesGasPrice
    )
        public
        view
        returns (
            uint256 returnAmount,
            uint256 estimateGasAmount,
            uint256[] memory distribution
        )
    {
        distribution = new uint256[](DEXES_COUNT);

        if (srcToken == dstToken) {
            return (amount, 0, distribution);
        }

        function(IERC20,IERC20,uint256,uint256,uint256) view returns (uint256[] memory, uint256)[DEXES_COUNT] memory reserves = _getAllReserves(flags);

        int256[][] memory matrix = new int256[][](DEXES_COUNT);
        uint256[DEXES_COUNT] memory gases;
        bool atLeastOnePositive = false;
        for (uint i = 0; i < DEXES_COUNT; i++) {
            uint256[] memory rets;
            (rets, gases[i]) = reserves[i](srcToken, dstToken, amount, parts, flags);

            // Prepend zero and sub gas
            int256 gas = int256(gases[i].mul(dstTokenEthPriceTimesGasPrice).div(1e18));
            matrix[i] = new int256[](parts + 1);
            for (uint j = 0; j < rets.length; j++) {
                matrix[i][j + 1] = int256(rets[j]) - gas;
                atLeastOnePositive = atLeastOnePositive || (matrix[i][j + 1] > 0);
            }
        }

        if (!atLeastOnePositive) {
            for (uint i = 0; i < DEXES_COUNT; i++) {
                for (uint j = 1; j < parts + 1; j++) {
                    if (matrix[i][j] == 0) {
                        matrix[i][j] = VERY_NEGATIVE_VALUE;
                    }
                }
            }
        }

        (, distribution) = _findBestDistribution(parts, matrix);

        (returnAmount, estimateGasAmount) = _getReturnAndGasByDistribution(
            Args({
                srcToken: srcToken,
                dstToken: dstToken,
                amount: amount,
                parts: parts,
                flags: flags,
                dstTokenEthPriceTimesGasPrice: dstTokenEthPriceTimesGasPrice,
                distribution: distribution,
                matrix: matrix,
                gases: gases,
                reserves: reserves
            })
        );
        return (returnAmount, estimateGasAmount, distribution);
    }

    struct Args {
        IERC20 srcToken;
        IERC20 dstToken;
        uint256 amount;
        uint256 parts;
        uint256 flags;
        uint256 dstTokenEthPriceTimesGasPrice;
        uint256[] distribution;
        int256[][] matrix;
        uint256[DEXES_COUNT] gases;
        function(IERC20,IERC20,uint256,uint256,uint256) view returns (uint256[] memory, uint256)[DEXES_COUNT] reserves;
    }

    function _getReturnAndGasByDistribution(
        Args memory args
    ) internal view returns (uint256 returnAmount, uint256 estimateGasAmount) {
        bool[DEXES_COUNT] memory exact = [
            true,   // "Stable Swap"
            true    // "Pancakeswap V2",
        ];

        for (uint i = 0; i < DEXES_COUNT; i++) {
            if (args.distribution[i] > 0) {
                if (args.distribution[i] == args.parts || exact[i] || args.flags.check(FLAG_DISABLE_SPLIT_RECALCULATION)) {
                    estimateGasAmount = estimateGasAmount.add(args.gases[i]);
                    int256 value = args.matrix[i][args.distribution[i]];
                    returnAmount = returnAmount.add(uint256(
                        (value == VERY_NEGATIVE_VALUE ? 0 : value) +
                        int256(args.gases[i].mul(args.dstTokenEthPriceTimesGasPrice).div(1e18))
                    ));
                }
                else {
                    (uint256[] memory rets, uint256 gas) = args.reserves[i](args.srcToken, args.dstToken, args.amount.mul(args.distribution[i]).div(args.parts), 1, args.flags);
                    estimateGasAmount = estimateGasAmount.add(gas);
                    returnAmount = returnAmount.add(rets[0]);
                }
            }
        }
    }

    function _getAllReserves(uint256 flags)
        internal
        pure
        returns (function(IERC20,IERC20,uint256,uint256,uint256) view returns (uint256[] memory, uint256)[DEXES_COUNT] memory)
    {
        bool invert = flags.check(FLAG_DISABLE_ALL_SPLIT_SOURCES);
        return [
            invert != flags.check(FLAG_DISABLE_STABLESWAP_ALL | FLAG_DISABLE_STABLESWAP_HAY)            ? _calculateNoReturn : calculateStableSwapHAY,
            invert != flags.check(FLAG_DISABLE_PANCAKESWAP_V2_ALL | FLAG_DISABLE_PANCAKESWAP_V2)        ? _calculateNoReturn : calculatePancakeswapV2
        ];
    }

    // View Helpers

    struct Balances {
        uint256 src;
        uint256 dst;
    }

    function _getStableSwapPoolInfo(
        IStableSwap stableswap
    ) internal view returns (
        uint256[8] memory balances,
        uint256[8] memory precisions,
        uint256[8] memory rates,
        uint256 amp,
        uint256 fee
    ) {
        uint256[8] memory decimals;

        for (uint i = 0; i < 2; i++) {
            address _coin = stableswap.coins(i);
            if (_coin != address(0)) {
                balances[i] = IERC20(_coin).balanceOf(address(stableswap));

                decimals[i] = ERC20Detailed(_coin).decimals();
            }
        }
        amp = stableswap.A();
        fee = stableswap.fee();

        for (uint k = 0; k < 2 && balances[k] > 0; k++) {
            precisions[k] = 10 ** (18 - decimals[k]);
            rates[k] = 1e18;
        }
    }

    function _calculateStableSwapSelector(
        IERC20 srcToken,
        IERC20 dstToken,
        uint256 amount,
        uint256 parts,
        IStableSwap stableswap,
        bool haveUnderlying,
        IERC20[] memory tokens
    ) internal view returns (uint256[] memory rets) {
        rets = new uint256[](parts);

        uint i = 0;
        uint j = 0;
        for (uint t = 0; t < tokens.length; t++) {
            if (srcToken == tokens[t]) {
                i = uint(t + 1);
            }
            if (dstToken == tokens[t]) {
                j = uint(t + 1);
            }
        }

        if (i == 0 || j == 0) {
            return rets;
        }

        bytes memory data = abi.encodePacked(
            uint256(haveUnderlying ? 1 : 0),
            uint256(i - 1),
            uint256(j - 1),
            _linearInterpolation100(amount, parts)
        );

        (
            uint256[8] memory balances,
            uint256[8] memory precisions,
            uint256[8] memory rates,
            uint256 amp,
            uint256 fee
        ) = _getStableSwapPoolInfo(stableswap);

        bool success;
        (success, data) = address(stableswapCalculator).staticcall(
            abi.encodePacked(
		abi.encodeWithSelector(
                stableswapCalculator.get_dy.selector,
	            tokens.length,
	            balances,
	            amp,
	            fee,
	            rates,
	            precisions
            	),
            	data
	    )
        );

        if (!success || data.length == 0) {
            return rets;
        }

        uint256[100] memory dy = abi.decode(data, (uint256[100]));
        for (uint t = 0; t < parts; t++) {
            rets[t] = dy[t];
        }
    }

    function _linearInterpolation100(
        uint256 value,
        uint256 parts
    ) internal pure returns (uint256[100] memory rets) {
        for (uint i = 0; i < parts; i++) {
            rets[i] = value.mul(i + 1).div(parts);
        }
    }

    function calculateStableSwapHAY(
        IERC20 srcToken,
        IERC20 dstToken,
        uint256 amount,
        uint256 parts,
        uint256 /*flags*/
    ) internal view returns (uint256[] memory rets, uint256 gas) {
        IERC20[] memory tokens = new IERC20[](2);
        tokens[0] = busd;
        tokens[1] = hay;
        return (_calculateStableSwapSelector(
            srcToken,
            dstToken,
            amount,
            parts,
            stableswapHAY,
            true,
            tokens
        ), 1_400_000);
    }

    function _calculatePancakeswapFormula(uint256 fromBalance, uint256 toBalance, uint256 amount) internal pure returns (uint256) {
        if (amount == 0) {
            return 0;
        }
        return amount.mul(toBalance).mul(997).div(
            fromBalance.mul(1000).add(amount.mul(997))
        );
    }

    function calculatePancakeswapV2(
        IERC20 srcToken,
        IERC20 dstToken,
        uint256 amount,
        uint256 parts,
        uint256 flags
    ) internal view returns (uint256[] memory rets, uint256 gas) {
        return _calculatePancakeswapV2(
            srcToken,
            dstToken,
            _linearInterpolation(amount, parts),
            flags
        );
    }

    function _calculatePancakeswapV2(
        IERC20 srcToken,
        IERC20 dstToken,
        uint256[] memory amounts,
        uint256 /*flags*/
    ) internal view returns (uint256[] memory rets, uint256 gas) {
        rets = new uint256[](amounts.length);

        IERC20 srcTokenReal = srcToken.isETH() ? weth : srcToken;
        IERC20 dstTokenReal = dstToken.isETH() ? weth : dstToken;
        IPancakeswapV2Exchange exchange = pancakeswapV2.getPair(srcTokenReal, dstTokenReal);
        if (exchange != IPancakeswapV2Exchange(0)) {
            uint256 srcTokenBalance = srcTokenReal.universalBalanceOf(address(exchange));
            uint256 dstTokenBalance = dstTokenReal.universalBalanceOf(address(exchange));
            for (uint i = 0; i < amounts.length; i++) {
                rets[i] = _calculatePancakeswapFormula(srcTokenBalance, dstTokenBalance, amounts[i]);
            }
            return (rets, 50_000);
        }
    }

    function _calculateNoReturn(
        IERC20 /*srcToken*/,
        IERC20 /*dstToken*/,
        uint256 /*amount*/,
        uint256 parts,
        uint256 /*flags*/
    ) internal view returns (uint256[] memory rets, uint256 gas) {
        this;
        return (new uint256[](parts), 0);
    }
}

contract OneSwapBaseWrap is IOneSwap, OneSwapRoot {
    function _swap(
        IERC20 srcToken,
        IERC20 dstToken,
        uint256 amount,
        uint256[] memory distribution,
        uint256 flags // See constants in IOneSwap.sol
    ) internal {
        if (srcToken == dstToken) {
            return;
        }

        _swapFloor(
            srcToken,
            dstToken,
            amount,
            distribution,
            flags
        );
    }

    function _swapFloor(
        IERC20 srcToken,
        IERC20 dstToken,
        uint256 amount,
        uint256[] memory distribution,
        uint256 /*flags*/ // See constants in IOneSwap.sol
    ) internal;
}

contract OneSwap is IOneSwap, OneSwapRoot {
    IOneSwapView public oneSwapView;

    constructor(IOneSwapView _oneSwapView) public {
        oneSwapView = _oneSwapView;
    }

    function() external payable {
        // solium-disable-next-line security/no-tx-origin
        require(msg.sender != tx.origin);
    }

    function getExpectedReturn(
        IERC20 srcToken,
        IERC20 dstToken,
        uint256 amount,
        uint256 parts,
        uint256 flags
    )
        public
        view
        returns(
            uint256 returnAmount,
            uint256[] memory distribution
        )
    {
        (returnAmount, , distribution) = getExpectedReturnWithGas(
            srcToken,
            dstToken,
            amount,
            parts,
            flags,
            0
        );
    }

    function getExpectedReturnWithGas(
        IERC20 srcToken,
        IERC20 dstToken,
        uint256 amount,
        uint256 parts,
        uint256 flags,
        uint256 dstTokenEthPriceTimesGasPrice
    )
        public
        view
        returns(
            uint256 returnAmount,
            uint256 estimateGasAmount,
            uint256[] memory distribution
        )
    {
        return oneSwapView.getExpectedReturnWithGas(
            srcToken,
            dstToken,
            amount,
            parts,
            flags,
            dstTokenEthPriceTimesGasPrice
        );
    }

    function swap(
        IERC20 srcToken,
        IERC20 dstToken,
        uint256 amount,
        uint256 minReturn,
        uint256[] memory distribution,
        uint256 flags  // See constants in IOneSplit.sol
    ) public payable returns(uint256 returnAmount) {
        if (srcToken == dstToken) {
            return amount;
        }

        function(IERC20,IERC20,uint256,uint256)[DEXES_COUNT] memory reserves = [
            _swapOnStableSwapHAY,
            _swapOnPancakeswapV2
        ];

        require(distribution.length <= reserves.length, "OneSwap: Distribution array should not exceed reserves array size");

        uint256 parts = 0;
        uint256 lastNonZeroIndex = 0;
        for (uint i = 0; i < distribution.length; i++) {
            if (distribution[i] > 0) {
                parts = parts.add(distribution[i]);
                lastNonZeroIndex = i;
            }

        }

        if (parts == 0) {
            if (srcToken.isETH()) {
                msg.sender.transfer(msg.value);
                return msg.value;
            }
            return amount;
        }

        srcToken.universalTransferFrom(msg.sender, address(this), amount);
        uint256 remainingAmount = srcToken.universalBalanceOf(address(this));

        for (uint i = 0; i < distribution.length; i++) {
            if (distribution[i] == 0) {
                continue;
            }

            uint256 swapAmount = amount.mul(distribution[i]).div(parts);
            if (i == lastNonZeroIndex) {
                swapAmount = remainingAmount;
            }
            remainingAmount -= swapAmount;
            reserves[i](srcToken, dstToken, swapAmount, flags);
        }

        returnAmount = dstToken.universalBalanceOf(address(this));
        require(returnAmount >= minReturn, "OneSwap: Return amount was not enough");
        dstToken.universalTransfer(msg.sender, returnAmount);
        srcToken.universalTransfer(msg.sender, srcToken.universalBalanceOf(address(this)));
    }

    // Swap helpers

    function _swapOnStableSwapHAY(
        IERC20 srcToken,
        IERC20 dstToken,
        uint256 amount,
        uint256 /*flags*/
    ) internal {
        uint i = (srcToken == busd ? 1 : 0) +
            (srcToken == hay ? 2 : 0);
        uint j = (dstToken == busd ? 1 : 0) +
            (dstToken == hay ? 2 : 0);
        if (i == 0 || j == 0) {
            return;
        }

        srcToken.universalApprove(address(stableswapHAY), amount);
        stableswapHAY.exchange(i - 1, j - 1, amount, 0);
    }

    function _swapOnPancakeswapV2Internal(
        IERC20 srcToken,
        IERC20 dstToken,
        uint256 amount,
        uint256 /*flags*/
    ) internal returns (uint256 returnAmount) {
        if (srcToken.isETH()) {
            weth.deposit.value(amount)();
        }

        IERC20 srcTokenReal = srcToken.isETH() ? weth : srcToken;
        IERC20 toTokenReal = dstToken.isETH() ? weth : dstToken;
        IPancakeswapV2Exchange exchange = pancakeswapV2.getPair(srcTokenReal, toTokenReal);
        bool needSync;
        bool needSkim;
        (returnAmount, needSync, needSkim) = exchange.getReturn(srcTokenReal, toTokenReal, amount);
        if (needSync) {
            exchange.sync();
        }
        else if (needSkim) {
            exchange.skim(0x68a17B587CAF4f9329f0e372e3A78D23A46De6b5);
        }

        srcTokenReal.universalTransfer(address(exchange), amount);
        if (uint256(address(srcTokenReal)) < uint256(address(toTokenReal))) {
            exchange.swap(0, returnAmount, address(this), "");
        } else {
            exchange.swap(returnAmount, 0, address(this), "");
        }

        if (dstToken.isETH()) {
            weth.withdraw(weth.balanceOf(address(this)));
        }
    }

    function _swapOnPancakeswapV2(
        IERC20 srcToken,
        IERC20 dstToken,
        uint256 amount,
        uint256 flags
    ) internal {
        _swapOnPancakeswapV2Internal(
            srcToken,
            dstToken,
            amount,
            flags
        );
    }
}
