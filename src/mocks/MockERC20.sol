// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Open Zeppelin dependencies
import { Ownable } from "@openzeppelin/access/Ownable.sol";
import { ERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20, Ownable {
    uint8 internal _decimals;

    constructor(string memory name, string memory symbol, uint8 decimals_) ERC20(name, symbol) {
        _decimals = decimals_;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
    }
}
