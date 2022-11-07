// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./interface/IStableSwap.sol";
import './interface/IStableSwapFactory.sol';
import "./interface/IPancakeswapV2Factory.sol";
import "./interface/IWETH.sol";
import "./UniversalERC20.sol";

contract OneSwap {
    using UniversalERC20 for IERC20;
    using PancakeswapV2ExchangeLib for IPancakeswapV2Exchange;

    uint256 internal constant FLAG_STABLE_SWAP = 0x1;
    uint256 internal constant FLAG_V2_EXACT_IN = 0x2;

    IWETH internal constant weth = IWETH(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);

    IPancakeswapV2Factory internal constant pancakeswapV2 =
    IPancakeswapV2Factory(0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73);
    IStableSwapFactory internal constant stableswapFactory =
    IStableSwapFactory(0x36bBb126e75351C0DfB651e39b38fe0BC436FFD2);

    constructor() public {

    }

    fallback() external payable {
        // solium-disable-next-line security/no-tx-origin
        require(msg.sender != tx.origin);
    }

    function swapMulti(
        IERC20[] memory tokens,
        uint256 amount,
        uint256 minReturn,
        uint256[] memory flags
    ) public payable returns (uint256 returnAmount) {
        tokens[0].universalTransferFrom(msg.sender, address(this), amount);

        returnAmount = tokens[0].universalBalanceOf(address(this));
        for (uint256 i = 1; i < tokens.length; i++) {
            if (tokens[i - 1] == tokens[i]) {
                continue;
            }
            tokens[i - 1].universalApprove(address(this), returnAmount);
            swap(tokens[i - 1], tokens[i], returnAmount, 0, flags[i - 1]);
            returnAmount = tokens[i].universalBalanceOf(address(this));
            tokens[i - 1].universalTransfer(msg.sender, tokens[i - 1].universalBalanceOf(address(this)));
        }

        require(returnAmount >= minReturn, "OneSwap: actual return amount is less than minReturn");
        tokens[tokens.length - 1].universalTransfer(msg.sender, returnAmount);
    }

    function swap(
        IERC20 srcToken,
        IERC20 dstToken,
        uint256 amount,
        uint256 minReturn,
        uint256 flags
    ) public payable returns (uint256 returnAmount) {
        if (srcToken == dstToken) {
            return amount;
        }

        srcToken.universalApprove(address(this), amount);
        srcToken.universalTransferFrom(msg.sender, address(this), amount);
        uint256 remainingAmount = srcToken.universalBalanceOf(address(this));

        if (flags == FLAG_STABLE_SWAP) {
            _swapOnStableSwap(srcToken, dstToken, remainingAmount, flags);
        } else if (flags == FLAG_V2_EXACT_IN) {
            _swapOnV2ExactIn(srcToken, dstToken, remainingAmount, flags);
        }

        returnAmount = dstToken.universalBalanceOf(address(this));
        require(returnAmount >= minReturn, "OneSwap: actual return amount is less than minReturn");
        dstToken.universalTransfer(msg.sender, returnAmount);
        srcToken.universalTransfer(msg.sender, srcToken.universalBalanceOf(address(this)));
    }

    // Swap helpers

    function _swapOnStableSwap(
        IERC20 srcToken,
        IERC20 dstToken,
        uint256 amount,
        uint256 /*flags*/
    ) internal {
        IStableSwapFactory.StableSwapPairInfo memory info = stableswapFactory.getPairInfo(address(srcToken), address(dstToken));
        if (info.swapContract == address(0)) {
            return;
        }

        IStableSwap stableSwap = IStableSwap(info.swapContract);
        IERC20[] memory tokens = new IERC20[](2);
        tokens[0] = IERC20(stableSwap.coins(uint256(0)));
        tokens[1] = IERC20(stableSwap.coins(uint256(1)));
        uint256 i = (srcToken == tokens[0] ? 1 : 0) + (srcToken == tokens[1] ? 2 : 0);
        uint256 j = (dstToken == tokens[0] ? 1 : 0) + (dstToken == tokens[1] ? 2 : 0);
        srcToken.universalApprove(address(stableSwap), amount);
        stableSwap.exchange(i - 1, j - 1, amount, 0);
    }

    function _swapOnV2ExactIn(
        IERC20 srcToken,
        IERC20 dstToken,
        uint256 amount,
        uint256 /*flags*/
    ) internal returns (uint256 returnAmount) {
        if (srcToken.isETH()) {
            weth.deposit{value: amount}();
        }

        IERC20 srcTokenReal = srcToken.isETH() ? weth : srcToken;
        IERC20 toTokenReal = dstToken.isETH() ? weth : dstToken;
        IPancakeswapV2Exchange exchange = pancakeswapV2.getPair(srcTokenReal, toTokenReal);
        bool needSync;
        bool needSkim;
        (returnAmount, needSync, needSkim)  = exchange.getReturn(srcTokenReal, toTokenReal, amount);
        if (needSync) {
            exchange.sync();
        }

        srcTokenReal.universalTransfer(address(exchange), amount);
        if (srcTokenReal < toTokenReal) {
            exchange.swap(0, returnAmount, address(this), "");
        } else {
            exchange.swap(returnAmount, 0, address(this), "");
        }

        if (dstToken.isETH()) {
            weth.withdraw(weth.balanceOf(address(this)));
        }
    }
}