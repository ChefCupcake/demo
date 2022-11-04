// SPDX-License-Identifier: MIT
pragma solidity ^0.5.0;

interface IStableSwapFactory {
    // solium-disable-next-line mixedcase
    function pairLength() external view returns (uint256);

    // solium-disable-next-line mixedcase
    function swapPairContract(uint256 i) external view returns (address);
}