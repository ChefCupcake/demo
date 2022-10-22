// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.5.0;

import './IUniswapExchange.sol';

interface IUniswapFactory {
    function getExchange(IERC20 token) external view returns (IUniswapExchange exchange);
}
