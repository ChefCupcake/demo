// SPDX-License-Identifier: MIT
pragma solidity ^0.5.0;

interface IStableSwap {
    // solium-disable-next-line mixedcase
    function get_dy(
        uint256 i,
        uint256 j,
        uint256 dx
    ) external view returns (uint256 dy);

    // solium-disable-next-line mixedcase
    function exchange(
        uint256 i,
        uint256 j,
        uint256 dx,
        uint256 minDy
    ) external;

    // solium-disable-next-line mixedcase
    function coins(uint256 i) external view returns (address);

    // solium-disable-next-line mixedcase
    function balances(uint256 i) external view returns (uint256);

    // solium-disable-next-line mixedcase
    function A() external view returns (uint256);

    // solium-disable-next-line mixedcase
    function fee() external view returns (uint256);
}

contract IStableSwapCalculator {
    function get_dy(
        int128 nCoins,
        uint256[8] calldata balances,
        uint256 amp,
        uint256 fee,
        uint256[8] calldata rates,
        uint256[8] calldata precisions,
        bool underlying,
        int128 i,
        int128 j,
        uint256[100] calldata dx
    ) external view returns (uint256[100] memory dy);
}
