// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin-4.5.0/contracts/token/ERC20/IERC20.sol";

interface IWETH is IERC20 {
    function deposit() external payable;

    function withdraw(uint256 amount) external;
}
