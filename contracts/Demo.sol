
// SPDX-License-Identifier: MIT
pragma solidity ^0.5.0;

import './interface/ICurve.sol';
import './interface/IPancakeswapV2Factory.sol';
import './interface/IStableSwap.sol';
import './interface/IStableSwapFactory.sol';
import './interface/IWETH.sol';
import '@openzeppelin-2.5.0/contracts/math/SafeMath.sol';
import '@openzeppelin-2.5.0/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin-2.5.0/contracts/token/ERC20/ERC20Detailed.sol';

contract Demo {
    using SafeMath for uint256;

    uint256 constant internal DEXES_COUNT = 2;
    IERC20 constant internal ETH_ADDRESS = IERC20(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
    IERC20 constant internal ZERO_ADDRESS = IERC20(0);

    IWETH constant internal weth = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 constant internal dai = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    IERC20 constant internal usdc = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20 constant internal usdt = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    IERC20 constant internal tusd = IERC20(0x0000000000085d4780B73119b644AE5ecd22b376);
    IERC20 constant internal busd = IERC20(0x4Fabb145d64652a948d72533023f6E7A623C7C53);
    IERC20 constant internal susd = IERC20(0x57Ab1ec28D129707052df4dF418D58a2D46d5f51);

    ICurve constant internal curveCompound = ICurve(0xA2B47E3D5c44877cca798226B7B8118F9BFb7A56);
    ICurve constant internal curveUSDT = ICurve(0x52EA46506B9CC5Ef470C5bf89f17Dc28bB35D85C);
    ICurve constant internal curveY = ICurve(0x45F783CCE6B7FF23B2ab2D70e416cdb7D6055f51);
    ICurve constant internal curveBinance = ICurve(0x79a8C46DeA5aDa233ABaFFD40F3A0A2B1e5A4F27);
    ICurve constant internal curveSynthetix = ICurve(0xA5407eAE9Ba41422680e2e00537571bcC53efBfD);
    ICurve constant internal curvePAX = ICurve(0x06364f10B501e868329afBc005b3492902d6C763);
    ICurve constant internal curveRenBTC = ICurve(0x93054188d876f558f4a66B2EF1d97d16eDf0895B);
    ICurve constant internal curveTBTC = ICurve(0x9726e9314eF1b96E45f40056bEd61A088897313E);
    ICurve constant internal curveSBTC = ICurve(0x7fC77b5c7614E1533320Ea6DDc2Eb61fa00A9714);
    IPancakeswapV2Factory constant internal uniswapV2 = IPancakeswapV2Factory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);
    ICurveCalculator constant internal curveCalculator = ICurveCalculator(0xc1DB00a8E5Ef7bfa476395cdbcc98235477cDE4E);
    ICurveRegistry constant internal curveRegistry = ICurveRegistry(0x7002B727Ef8F5571Cb5F9D70D13DBEEb4dFAe9d1);
    IStableSwapFactory constant internal stableswapFactory = IStableSwapFactory(0x36bBb126e75351C0DfB651e39b38fe0BC436FFD2);

    function _getCurvePoolInfo(
        ICurve curve,
        bool haveUnderlying
    ) internal view returns(
        uint256[8] memory balances,
        uint256[8] memory precisions,
        uint256[8] memory rates,
        uint256 amp,
        uint256 fee
    ) {
        uint256[8] memory underlying_balances;
        uint256[8] memory decimals;
        uint256[8] memory underlying_decimals;

        (
            balances,
            underlying_balances,
            decimals,
            underlying_decimals,
            /*address lp_token*/,
            amp,
            fee
        ) = curveRegistry.get_pool_info(address(curve));

        for (uint k = 0; k < 8 && balances[k] > 0; k++) {
            precisions[k] = 10 ** (18 - (haveUnderlying ? underlying_decimals : decimals)[k]);
            if (haveUnderlying) {
                rates[k] = underlying_balances[k].mul(1e18).div(balances[k]);
            } else {
                rates[k] = 1e18;
            }
        }
    }

    function _calculateCurveSelector(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount,
        uint256 parts,
        ICurve curve,
        bool haveUnderlying,
        IERC20[] memory tokens
    ) internal view returns(uint256[] memory rets) {
        rets = new uint256[](parts);

        int128 i = 0;
        int128 j = 0;
        for (uint t = 0; t < tokens.length; t++) {
            if (fromToken == tokens[t]) {
                i = int128(t + 1);
            }
            if (destToken == tokens[t]) {
                j = int128(t + 1);
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
        ) = _getCurvePoolInfo(curve, haveUnderlying);

        bool success;
        (success, data) = address(curveCalculator).staticcall(
            abi.encodePacked(
                abi.encodeWithSelector(
                    curveCalculator.get_dy.selector,
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
    ) internal pure returns(uint256[100] memory rets) {
        for (uint i = 0; i < parts; i++) {
            rets[i] = value.mul(i + 1).div(parts);
        }
    }

    function calculateCurve(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount,
        uint256 parts,
        uint256 /*flags*/
    ) external view returns (uint256[] memory rets, uint256 maxRets, uint256 gas) {
//        uint256 totalRets;
//        IERC20[] memory tokens = new IERC20[](2);
//        tokens[0] = dai;
//        tokens[1] = usdc;
//        uint256[] memory _rets = _calculateCurveSelector(
//            fromToken,
//            destToken,
//            amount,
//            parts,
//            curveCompound,
//            true,
//            tokens
//        );
//        totalRets = 0;
//        for (uint j = 0; j < parts; j++) {
//            totalRets = totalRets.add(_rets[j]);
//        }
//        if (maxRets < totalRets) {
//            rets = _rets;
//            maxRets = totalRets;
//        }
        uint256 totalRets;
        uint256 pairLength = stableswapFactory.pairLength();
        maxRets = pairLength;
        for (uint i = 0; i < pairLength; i++) {
            IStableSwap stableSwap = IStableSwap(stableswapFactory.swapPairContract(i));
            IERC20[] memory tokens = new IERC20[](2);
            tokens[0] = IERC20(stableSwap.coins(uint(0)));
            tokens[1] = IERC20(stableSwap.coins(uint(1)));
        }

        return (rets, maxRets, 720_000);
    }

}