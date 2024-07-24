// SPDX-License-Identifier: UNLCICENSED
pragma solidity 0.8.25;

// Open Zeppelin Upgradeable dependencies
import { Initializable } from "@openzeppelin-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/access/OwnableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { ERC4626Upgradeable } from "@openzeppelin-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";

contract ZlpVault is Initializable, UUPSUpgradeable, OwnableUpgradeable, ERC4626Upgradeable {
    function _authorizeUpgrade(address) internal override onlyOwner { }
}
