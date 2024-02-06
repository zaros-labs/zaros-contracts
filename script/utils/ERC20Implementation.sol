// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Open Zeppelin dependencies
import { Ownable } from "@openzeppelin/access/Ownable.sol";
import { ERC20, ERC20Permit } from "@openzeppelin/token/ERC20/extensions/ERC20Permit.sol";

contract ERC20Implementation is ERC20Permit, Ownable {
    constructor(address owner, string memory name, string memory symbol) ERC20(name, symbol) ERC20Permit("Zaros USD") Ownable(owner) { }

    uint256 MAX_AMOUNT_MINT = 100_000 * 10 ** 18;
    mapping(address user => uint256 amount) public amountMintedPerAddress;

    error ERC20Token_ZeroAmount();

    function mint(address to, uint256 amount) external {
        _requireAmountNotZero(amount);
        _requireAmountLessThanMaxAmountMint(amount);

        amountMintedPerAddress[msg.sender] += amount;

        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external {
        _requireAmountNotZero(amount);
        _burn(from, amount);
    }

    function _requireAmountNotZero(uint256 amount) private pure {
        if (amount == 0) {
            revert ERC20Token_ZeroAmount();
        }
    }

    function _requireAmountLessThanMaxAmountMint(uint256 amount) private view {
        require(amountMintedPerAddress[msg.sender] + amount <= MAX_AMOUNT_MINT, "You have exceeded your mint limit");
    }

    function updateMaxAmountMint(uint256 newAmount) public onlyOwner {
        MAX_AMOUNT_MINT = newAmount;
    }
}
