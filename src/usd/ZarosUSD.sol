// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { IZarosUSD } from "./interfaces/IZarosUSD.sol";

// Open Zeppelin dependencies
import { Ownable } from "@openzeppelin/access/Ownable.sol";
import { ERC20, ERC20Permit } from "@openzeppelin/token/ERC20/extensions/ERC20Permit.sol";

contract ZarosUSD is IZarosUSD, ERC20Permit, Ownable {
    constructor() ERC20("Zaros USD", "zrsUSD") ERC20Permit("Zaros USD") { }

    function mint(address to, uint256 amount) external onlyOwner {
        _requireAmountNotZero(amount);
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyOwner {
        _requireAmountNotZero(amount);
        _burn(from, amount);
    }

    function _requireAmountNotZero(uint256 amount) private pure {
        if (amount == 0) {
            revert ZarosUSD_ZeroAmount();
        }
    }
}
