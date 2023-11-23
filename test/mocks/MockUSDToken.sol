// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { USDToken } from "@zaros/usd/USDToken.sol";

contract MockUSDToken is USDToken {
    constructor(uint256 ownerBalance) {
        _mint(msg.sender, ownerBalance);
    }
}
