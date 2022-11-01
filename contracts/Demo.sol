// SPDX-License-Identifier: MIT
pragma solidity ^0.5.0;

import './interface/IStableSwap.sol';
import './interface/IWETH.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol';

contract Demo {
    using SafeMath for uint256;

    uint256 constant internal DEXES_COUNT = 2;
    IERC20 constant internal ETH_ADDRESS = IERC20(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
    IERC20 constant internal ZERO_ADDRESS = IERC20(0);

    IWETH constant internal weth = IWETH(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IERC20 constant internal busd = IERC20(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);
    IERC20 constant internal hay = IERC20(0x0782b6d8c4551B9760e74c0545a9bCD90bdc41E5);

    IStableSwap constant internal stableswapHAY = IStableSwap(0x49079D07ef47449aF808A4f36c2a8dEC975594eC);
    IStableSwapCalculator constant internal stableswapCalculator = IStableSwapCalculator(0x4b1bFb6f5E2B10770F08e2496E8d0CdB2e682798);

    function getStableSwapPoolInfo(

    ) external view returns (
        uint256[8] memory balances,
        uint256[8] memory precisions,
        uint256[8] memory rates,
        uint256 amp,
        uint256 fee
    ) {
        uint256[8] memory decimals;

        for (uint i = 0; i < 2; i++) {
            address _coin = stableswapHAY.coins(i);
            if (_coin != address(0)) {
                balances[i] = IERC20(_coin).balanceOf(address(stableswapHAY));

                decimals[i] = ERC20Detailed(_coin).decimals();
            }
        }
        amp = stableswapHAY.A();
        fee = stableswapHAY.fee();

//        (
//            balances,
//            /*underlying_balances*/,
//            decimals,
//            /*underlying_decimals*/,
//            /*address lp_token*/,
//            amp,
//            fee
//        ) = curveRegistry.get_pool_info(address(curveHAY));

        for (uint k = 0; k < 2 && balances[k] > 0; k++) {
            precisions[k] = 10 ** (18 - decimals[k]);
            rates[k] = 1e18;
        }
    }

}