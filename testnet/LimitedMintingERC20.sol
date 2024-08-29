// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Open zeppelin upgradeable dependencies
import { ERC20PermitUpgradeable } from "@openzeppelin-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/access/OwnableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract LimitedMintingERC20 is UUPSUpgradeable, ERC20PermitUpgradeable, OwnableUpgradeable {
    uint256 internal maxAmountToMintPerAddress;
    mapping(address user => uint256 amount) public amountMintedPerAddress;

    error LimitedMintingERC20_ZeroAmount();
    error LimitedMintingERC20_AmountExceedsLimit();
    error LimitedMintingERC20_UserIsNotActive();

    uint256 private constant AMOUNT_TO_MINT_USDC = 100_000 * 10 ** 18;

    function getAmountMintedPerAddress(address user) public view returns (uint256) {
        return amountMintedPerAddress[user];
    }

    function initialize(address owner, string memory name, string memory symbol) external initializer {
        maxAmountToMintPerAddress = 100_000 * 10 ** 18;

        __ERC20_init(name, symbol);
        __ERC20Permit_init(name);
        __Ownable_init(owner);
    }

    function transfer(address to, uint256 value) public virtual override onlyOwner returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) public virtual override onlyOwner returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, value);
        _transfer(from, to, value);
        return true;
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function mint() external {
        amountMintedPerAddress[msg.sender] += AMOUNT_TO_MINT_USDC;

        _mint(msg.sender, AMOUNT_TO_MINT_USDC);
    }

    function burn(address from, uint256 amount) external {
        _requireAmountNotZero(amount);
        _burn(from, amount);
    }

    function updateMaxAmountToMintPerAddress(uint256 newAmount) external onlyOwner {
        maxAmountToMintPerAddress = newAmount;
    }

    function _requireAmountNotZero(uint256 amount) private pure {
        if (amount == 0) revert LimitedMintingERC20_ZeroAmount();
    }

    function _requireAmountLessThanMaxAmountMint(uint256 amount) private view {
        if (amountMintedPerAddress[msg.sender] + amount > maxAmountToMintPerAddress) {
            revert LimitedMintingERC20_AmountExceedsLimit();
        }
    }

    function _authorizeUpgrade(address) internal override onlyOwner { }
}
