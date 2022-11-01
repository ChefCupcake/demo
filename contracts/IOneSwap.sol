// SPDX-License-Identifier: MIT
pragma solidity ^0.5.0;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

contract IOneSwapConsts {
    uint256 internal constant FLAG_DISABLE_STABLESWAP_HAY = 0x40000;
    uint256 internal constant FLAG_DISABLE_PANCAKESWAP_V2 = 0x2000000;
    uint256 internal constant FLAG_DISABLE_ALL_SPLIT_SOURCES = 0x20000000;
    uint256 internal constant FLAG_DISABLE_ALL_WRAP_SOURCES = 0x40000000;
    uint256 internal constant FLAG_DISABLE_STABLESWAP_ALL = 0x200000000000;
    uint256 internal constant FLAG_DISABLE_PANCAKESWAP_V2_ALL = 0x400000000000;
    uint256 internal constant FLAG_DISABLE_SPLIT_RECALCULATION = 0x800000000000;
}

contract IOneSwap is IOneSwapConsts {
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

    function swap(
        IERC20 srcToken,
        IERC20 dstToken,
        uint256 amount,
        uint256 minReturn,
        uint256[] memory distribution,
        uint256 flags
    )
        public
        payable
        returns (uint256 returnAmount);
}

contract IOneSwapMulti is IOneSwap {
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
        );

    function swapMulti(
        IERC20[] memory tokens,
        uint256 amount,
        uint256 minReturn,
        uint256[] memory distribution,
        uint256[] memory flags
    )
        public
        payable
        returns(uint256 returnAmount);
}