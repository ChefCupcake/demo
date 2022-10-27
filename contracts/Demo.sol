// SPDX-License-Identifier: MIT
pragma solidity ^0.5.0;

import './interface/ICurve.sol';
import './interface/IWETH.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol';
import 'hardhat/console.sol';

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

    ICurve constant internal curveHAY = ICurve(0x45F783CCE6B7FF23B2ab2D70e416cdb7D6055f51);
    ICurveCalculator constant internal curveCalculator = ICurveCalculator(0xc1DB00a8E5Ef7bfa476395cdbcc98235477cDE4E);
    ICurveRegistry constant internal curveRegistry = ICurveRegistry(0x7002B727Ef8F5571Cb5F9D70D13DBEEb4dFAe9d1);

    function getCurvePoolInfo(

    ) external view returns (
        uint256[8] memory balances,
        uint256[8] memory precisions,
        uint256[8] memory rates,
        uint256 amp,
        uint256 fee
    ) {
        uint256[8] memory decimals;

        for (int128 i = 0; i < 4; i++) {
            address _coin = curveHAY.coins(i);
            if (_coin != address(0)) {
                uint j = uint(i);
                balances[j] = IERC20(_coin).balanceOf(address(curveHAY));

                decimals[j] = ERC20Detailed(_coin).decimals();
            }
        }
        amp = curveHAY.A();
        fee = curveHAY.fee();

//        (
//            balances,
//            /*underlying_balances*/,
//            decimals,
//            /*underlying_decimals*/,
//            /*address lp_token*/,
//            amp,
//            fee
//        ) = curveRegistry.get_pool_info(address(curveHAY));

        for (uint k = 0; k < 8 && balances[k] > 0; k++) {
            precisions[k] = 10 ** (18 - decimals[k]);
            rates[k] = 1e18;
        }
    }

}