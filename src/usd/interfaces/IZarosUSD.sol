// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Open Zeppelin dependencies
import { IERC20 } from "@openzeppelin/token/ERC20/IERC20.sol";

interface IZarosUSD is IERC20 {
    error ZarosUSD_ZeroAmount(address target);

    function mint(address to, uint256 amount) external;

    function burn(address from, uint256 amount) external;
}
