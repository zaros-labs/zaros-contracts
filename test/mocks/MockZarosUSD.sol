// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { ZarosUSD } from "@zaros/usd/ZarosUSD.sol";

contract MockZarosUSD is ZarosUSD {
    constructor(uint256 ownerBalance) {
        _mint(msg.sender, ownerBalance);
    }
}
