// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin-4.5.0/contracts/utils/math/Math.sol";
import "@openzeppelin-4.5.0/contracts/utils/math/SafeMath.sol";
import "@openzeppelin-4.5.0/contracts/token/ERC20/IERC20.sol";
import "../UniversalERC20.sol";

interface IPancakeswapV2Exchange {
    function getReserves()
        external
        view
        returns (
            uint112 _reserve0,
            uint112 _reserve1,
            uint32 _blockTimestampLast
        );

    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes calldata data
    ) external;

    function skim(address to) external;

    function sync() external;
}

library PancakeswapV2ExchangeLib {
    using Math for uint256;
    using SafeMath for uint256;
    using UniversalERC20 for IERC20;

    function getReturn(
        IPancakeswapV2Exchange exchange,
        IERC20 srcToken,
        IERC20 dstToken,
        uint256 amountIn
    )
        internal
        view
        returns (
            uint256 result,
            bool needSync,
            bool needSkim
        )
    {
        uint256 reserveIn = srcToken.universalBalanceOf(address(exchange));
        uint256 reserveOut = dstToken.universalBalanceOf(address(exchange));
        (uint112 reserve0, uint112 reserve1, ) = exchange.getReserves();
        if (srcToken > dstToken) {
            (reserve0, reserve1) = (reserve1, reserve0);
        }
        needSync = (reserveIn < reserve0 || reserveOut < reserve1);
        needSkim = !needSync && (reserveIn > reserve0 || reserveOut > reserve1);

        uint256 amountInWithFee = amountIn.mul(9975);
        uint256 numerator = amountInWithFee.mul(Math.min(reserveOut, reserve1));
        uint256 denominator = Math.min(reserveIn, reserve0).mul(10000).add(amountInWithFee);
        result = (denominator == 0) ? 0 : numerator.div(denominator);
    }
}
