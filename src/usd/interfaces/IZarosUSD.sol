// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Open Zeppelin dependencies
import { IERC20 } from "@openzeppelin/token/ERC20/IERC20.sol";
import { Ownable } from "@openzeppelin/access/Ownable.sol";

interface IZarosUSD is IERC20 {
    error ZarosUSD_ZeroAmount();

    function mint(address to, uint256 amount) external;

    function burn(address from, uint256 amount) external;
}
