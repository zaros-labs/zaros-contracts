// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { USDToken } from "@zaros/usd/USDToken.sol";

contract MockUSDToken is USDToken {
    constructor(address owner, uint256 ownerBalance) USDToken(owner) {
        _mint(owner, ownerBalance);
    }
}
