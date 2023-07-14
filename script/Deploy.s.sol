// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

// Zaros dependencies
import { BaseScript } from "./Base.s.sol";
import { Zaros } from "@zaros/core/Zaros.sol";
import { AccountNFT } from "@zaros/account-nft/AccountNFT.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract Deploy is BaseScript {
    function run() public broadcaster returns (address) {
        AccountNFT accountNFT = new AccountNFT();
        Zaros zaros = new Zaros(address(accountNFT));

        return address(zaros);
    }
}
