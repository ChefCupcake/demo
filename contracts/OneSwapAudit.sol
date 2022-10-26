// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.5.0;

import '@openzeppelin/contracts/math/Math.sol';
import '@openzeppelin/contracts/ownership/Ownable.sol';
import './interface/IWETH.sol';
import './interface/IUniswapV2Exchange.sol';
import './IOneSwap.sol';
import './UniversalERC20.sol';

library Array {
    function first(IERC20[] memory arr) internal pure returns (IERC20) {
        return arr[0];
    }

    function last(IERC20[] memory arr) internal pure returns (IERC20) {
        return arr[arr.length - 1];
    }
}

//
// Security assumptions:
// 1. It is safe to have infinite approves of any tokens to this smart contract,
//    since it could only call `transferFrom()` with first argument equal to msg.sender
// 2. It is safe to call `swap()` with reliable `minReturn` argument,
//    if returning amount will not reach `minReturn` value whole swap will be reverted.
//
contract OneSwapAudit is IOneSwap, Ownable {
    using SafeMath for uint256;
    using UniversalERC20 for IERC20;
    using Array for IERC20[];

    IWETH constant internal weth = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    IOneSwapMulti public oneSwapImpl;

    event ImplementationUpdated(address indexed newImpl);

    event Swapped(
        IERC20 indexed srcToken,
        IERC20 indexed dstToken,
        uint256 srcTokenAmount,
        uint256 dstTokenAmount,
        uint256 minReturn,
        uint256[] distribution,
        uint256[] flags
    );

    constructor(IOneSwapMulti impl) public {
        setNewImpl(impl);
    }

    function() external payable {
        // solium-disable-next-line security/no-tx-origin
        require(msg.sender != tx.origin, "OneSwap: do not send ETH directly");
    }

    function setNewImpl(IOneSwapMulti impl) public onlyOwner {
        oneSwapImpl = impl;
        emit ImplementationUpdated(address(impl));
    }

    /// @notice Calculate expected returning amount of `dstToken`
    /// @param srcToken (IERC20) Address of token or `address(0)` for Ether
    /// @param dstToken (IERC20) Address of token or `address(0)` for Ether
    /// @param amount (uint256) Amount for `srcToken`
    /// @param parts (uint256) Number of pieces source volume could be splitted,
    /// works like granularity, higly affects gas usage. Should be called offchain,
    /// but could be called onchain if user swaps not his own funds, but this is still considered as not safe.
    /// @param flags (uint256) Flags for enabling and disabling some features, default 0
    function getExpectedReturn(
        IERC20 srcToken,
        IERC20 dstToken,
        uint256 amount,
        uint256 parts,
        uint256 flags // See contants in IOneSwap.sol
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

    /// @notice Calculate expected returning amount of `dstToken`
    /// @param srcToken (IERC20) Address of token or `address(0)` for Ether
    /// @param dstToken (IERC20) Address of token or `address(0)` for Ether
    /// @param amount (uint256) Amount for `srcToken`
    /// @param parts (uint256) Number of pieces source volume could be splitted,
    /// works like granularity, higly affects gas usage. Should be called offchain,
    /// but could be called onchain if user swaps not his own funds, but this is still considered as not safe.
    /// @param flags (uint256) Flags for enabling and disabling some features, default 0
    /// @param dstTokenEthPriceTimesGasPrice (uint256) dstToken price to ETH multiplied by gas price
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
        return oneSwapImpl.getExpectedReturnWithGas(
            srcToken,
            dstToken,
            amount,
            parts,
            flags,
            dstTokenEthPriceTimesGasPrice
        );
    }

    /// @notice Calculate expected returning amount of first `tokens` element to
    /// last `tokens` element through ann the middle tokens with corresponding
    /// `parts`, `flags` and `dstTokenEthPriceTimesGasPrices` array values of each step
    /// @param tokens (IERC20[]) Address of token or `address(0)` for Ether
    /// @param amount (uint256) Amount for `srcToken`
    /// @param parts (uint256[]) Number of pieces source volume could be splitted
    /// @param flags (uint256[]) Flags for enabling and disabling some features, default 0
    /// @param dstTokenEthPriceTimesGasPrices (uint256[]) dstToken price to ETH multiplied by gas price
    function getExpectedReturnWithGasMulti(
        IERC20[] memory tokens,
        uint256 amount,
        uint256[] memory parts,
        uint256[] memory flags,
        uint256[] memory dstTokenEthPriceTimesGasPrices
    )
        public
        view
        returns (
            uint256[] memory returnAmounts,
            uint256 estimateGasAmount,
            uint256[] memory distribution
        )
    {
        return oneSwapImpl.getExpectedReturnWithGasMulti(
            tokens,
            amount,
            parts,
            flags,
            dstTokenEthPriceTimesGasPrices
        );
    }

    /// @notice Swap `amount` of `srcToken` to `dstToken`
    /// @param srcToken (IERC20) Address of token or `address(0)` for Ether
    /// @param dstToken (IERC20) Address of token or `address(0)` for Ether
    /// @param amount (uint256) Amount for `srcToken`
    /// @param minReturn (uint256) Minimum expected return, else revert
    /// @param distribution (uint256[]) Array of weights for volume distribution returned by `getExpectedReturn`
    /// @param flags (uint256) Flags for enabling and disabling some features, default 0
    function swap(
        IERC20 srcToken,
        IERC20 dstToken,
        uint256 amount,
        uint256 minReturn,
        uint256[] memory distribution,
        uint256 flags // See constants in IOneSwap.sol
    ) public payable returns(uint256) {
        IERC20[] memory tokens = new IERC20[](2);
        tokens[0] = srcToken;
        tokens[1] = dstToken;

        uint256[] memory flagsArray = new uint256[](1);
        flagsArray[0] = flags;

        return swapMulti(
            tokens,
            amount,
            minReturn,
            distribution,
            flagsArray
        );
    }

    /// @notice Swap `amount` of first element of `tokens` to the latest element of `dstToken`
    /// @param tokens (IERC20[]) Addresses of token or `address(0)` for Ether
    /// @param amount (uint256) Amount for `srcToken`
    /// @param minReturn (uint256) Minimum expected return, else revert
    /// @param distribution (uint256[]) Array of weights for volume distribution returned by `getExpectedReturn`
    /// @param flags (uint256[]) Flags for enabling and disabling some features, default 0
    function swapMulti(
        IERC20[] memory tokens,
        uint256 amount,
        uint256 minReturn,
        uint256[] memory distribution,
        uint256[] memory flags
    ) public payable returns(uint256 returnAmount) {
        require(tokens.length >= 2 && amount > 0, "OneSwap: swap makes no sense");
        require(flags.length == tokens.length - 1, "OneSwap: flags array length is invalid");
        require((msg.value != 0) == tokens.first().isETH(), "OneSwap: msg.value should be used only for ETH swap");

        Balances memory beforeBalances = _getFirstAndLastBalances(tokens, true);

        // Transfer From
        if (amount == uint256(-1)) {
            amount = Math.min(
                tokens.first().balanceOf(msg.sender),
                tokens.first().allowance(msg.sender, address(this))
            );
        }
        tokens.first().universalTransferFromSenderToThis(amount);
        uint256 confirmed = tokens.first().universalBalanceOf(address(this)).sub(beforeBalances.ofSrcToken);

        // Swap
        tokens.first().universalApprove(address(oneSwapImpl), confirmed);
        oneSwapImpl.swapMulti.value(tokens.first().isETH() ? confirmed : 0)(
            tokens,
            confirmed,
            minReturn,
            distribution,
            flags
        );

        Balances memory afterBalances = _getFirstAndLastBalances(tokens, false);

        // Return
        returnAmount = afterBalances.ofDstToken.sub(beforeBalances.ofDstToken);
        require(returnAmount >= minReturn, "OneSwap: actual return amount is less than minReturn");

        emit Swapped(
            tokens.first(),
            tokens.last(),
            amount,
            returnAmount,
            minReturn,
            distribution,
            flags
        );

        // Return remainder
        if (afterBalances.ofSrcToken > beforeBalances.ofSrcToken) {
            tokens.first().universalTransfer(msg.sender, afterBalances.ofSrcToken.sub(beforeBalances.ofSrcToken));
        }
    }

    function claimAsset(IERC20 asset, uint256 amount) public onlyOwner {
        asset.universalTransfer(msg.sender, amount);
    }

    struct Balances {
        uint256 ofSrcToken;
        uint256 ofDstToken;
    }

    function _getFirstAndLastBalances(IERC20[] memory tokens, bool subValue) internal view returns(Balances memory) {
        return Balances({
            ofSrcToken: tokens.first().universalBalanceOf(address(this)).sub(subValue ? msg.value : 0),
            ofDstToken: tokens.last().universalBalanceOf(address(this))
        });
    }
}