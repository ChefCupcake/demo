// SPDX-License-Identifier: MIT
pragma solidity ^0.5.0;

import "./IOneSwap.sol";
import "./OneSwapBase.sol";

contract OneSwapViewWrap is OneSwapViewWrapBase {
    IOneSwapView public oneSwapView;

    constructor(IOneSwapView _oneSwap) public {
        oneSwapView = _oneSwap;
    }

    function getExpectedReturn(
        IERC20 srcToken,
        IERC20 dstToken,
        uint256 amount,
        uint256 parts,
        uint256 flags
    ) public view returns (uint256 returnAmount, uint256[] memory distribution) {
        (returnAmount, , distribution) = getExpectedReturnWithGas(srcToken, dstToken, amount, parts, flags, 0);
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
        if (srcToken == dstToken) {
            return (amount, 0, new uint256[](DEXES_COUNT));
        }

        return super.getExpectedReturnWithGas(srcToken, dstToken, amount, parts, flags, dstTokenEthPriceTimesGasPrice);
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
        )
    {
        return
            oneSwapView.getExpectedReturnWithGas(
                srcToken,
                dstToken,
                amount,
                parts,
                flags,
                dstTokenEthPriceTimesGasPrice
            );
    }
}

contract OneSwapWrap is OneSwapBaseWrap {
    IOneSwapView public oneSwapView;
    IOneSwap public oneSwap;

    constructor(IOneSwapView _oneSwapView, IOneSwap _oneSwap) public {
        oneSwapView = _oneSwapView;
        oneSwap = _oneSwap;
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
    ) public view returns (uint256 returnAmount, uint256[] memory distribution) {
        (returnAmount, , distribution) = getExpectedReturnWithGas(srcToken, dstToken, amount, parts, flags, 0);
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
        return
            oneSwapView.getExpectedReturnWithGas(
                srcToken,
                dstToken,
                amount,
                parts,
                flags,
                dstTokenEthPriceTimesGasPrice
            );
    }

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
        uint256[] memory dist;

        returnAmounts = new uint256[](tokens.length - 1);
        for (uint256 i = 1; i < tokens.length; i++) {
            if (tokens[i - 1] == tokens[i]) {
                returnAmounts[i - 1] = (i == 1) ? amount : returnAmounts[i - 1];
                continue;
            }

            IERC20[] memory _tokens = tokens;

            (returnAmounts[i - 1], amount, dist) = getExpectedReturnWithGas(
                _tokens[i - 1],
                _tokens[i],
                (i == 1) ? amount : returnAmounts[i - 2],
                parts[i - 1],
                flags[i - 1],
                dstTokenEthPriceTimesGasPrices[i - 1]
            );
            estimateGasAmount = estimateGasAmount.add(amount);

            if (distribution.length == 0) {
                distribution = new uint256[](dist.length);
            }
            for (uint256 j = 0; j < distribution.length; j++) {
                distribution[j] = distribution[j].add(dist[j] << (8 * (i - 1)));
            }
        }
    }

    function swap(
        IERC20 srcToken,
        IERC20 dstToken,
        uint256 amount,
        uint256 minReturn,
        uint256[] memory distribution,
        uint256 flags
    ) public payable returns (uint256 returnAmount) {
        srcToken.universalTransferFrom(msg.sender, address(this), amount);
        uint256 confirmed = srcToken.universalBalanceOf(address(this));
        _swap(srcToken, dstToken, confirmed, distribution, flags);

        returnAmount = dstToken.universalBalanceOf(address(this));
        require(returnAmount >= minReturn, "OneSwap: actual return amount is less than minReturn");
        dstToken.universalTransfer(msg.sender, returnAmount);
        srcToken.universalTransfer(msg.sender, srcToken.universalBalanceOf(address(this)));
    }

    function swapMulti(
        IERC20[] memory tokens,
        uint256 amount,
        uint256 minReturn,
        uint256[] memory distribution,
        uint256[] memory flags
    ) public payable returns (uint256 returnAmount) {
        tokens[0].universalTransferFrom(msg.sender, address(this), amount);

        returnAmount = tokens[0].universalBalanceOf(address(this));
        for (uint256 i = 1; i < tokens.length; i++) {
            if (tokens[i - 1] == tokens[i]) {
                continue;
            }

            uint256[] memory dist = new uint256[](distribution.length);
            for (uint256 j = 0; j < distribution.length; j++) {
                dist[j] = (distribution[j] >> (8 * (i - 1))) & 0xFF;
            }

            _swap(tokens[i - 1], tokens[i], returnAmount, dist, flags[i - 1]);
            returnAmount = tokens[i].universalBalanceOf(address(this));
            tokens[i - 1].universalTransfer(msg.sender, tokens[i - 1].universalBalanceOf(address(this)));
        }

        require(returnAmount >= minReturn, "OneSwap: actual return amount is less than minReturn");
        tokens[tokens.length - 1].universalTransfer(msg.sender, returnAmount);
    }

    function _swapFloor(
        IERC20 srcToken,
        IERC20 dstToken,
        uint256 amount,
        uint256[] memory distribution,
        uint256 flags
    ) internal {
        srcToken.universalApprove(address(oneSwap), amount);
        oneSwap.swap.value(srcToken.isETH() ? amount : 0)(srcToken, dstToken, amount, 0, distribution, flags);
    }
}
