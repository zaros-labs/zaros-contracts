// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { BaseScript } from "../Base.s.sol";
import { USDToken } from "@zaros/usd/USDToken.sol";
import { Constants } from "@zaros/utils/Constants.sol";
import { FeatureFlag } from "@zaros/utils/storage/FeatureFlag.sol";
import { IUSDToken } from "@zaros/usd/interfaces/IUSDToken.sol";

// Open Zeppelin dependencies
import { Ownable } from "@openzeppelin/access/Ownable.sol";
import { ERC20, ERC20Permit } from "@openzeppelin/token/ERC20/extensions/ERC20Permit.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract DeployLimitedMintingToken is BaseScript {
    function run() public broadcaster returns (address) {
        address limitedUSDToken = address(new LimitedUSDToken(deployer));

        return limitedUSDToken;
    }
}

contract LimitedUSDToken is IUSDToken, ERC20Permit, Ownable {
    constructor(address owner) ERC20("Zaros USD", "USDz") ERC20Permit("Zaros USD") Ownable(owner) { }

    uint256 MAX_AMOUNT_MINT = 100_000 * 10 ** 18;
    mapping(address => uint256) public quantityMintPerWallet;

    function mint(address to, uint256 amount) external {
        _requireAmountNotZero(amount);
        _requireAmountLessThanMaxAmountMint(amount);

        quantityMintPerWallet[msg.sender] += amount;

        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external {
        _requireAmountNotZero(amount);
        _burn(from, amount);
    }

    function _requireAmountNotZero(uint256 amount) private pure {
        if (amount == 0) {
            revert USDToken_ZeroAmount();
        }
    }

    function _requireAmountLessThanMaxAmountMint(uint256 amount) private view {
        require(quantityMintPerWallet[msg.sender] + amount <= MAX_AMOUNT_MINT, "You have exceeded your mint limit");
    }

    function updateMaxAmountMint(uint256 newAmount) public onlyOwner {
        MAX_AMOUNT_MINT = newAmount;
    }
}
