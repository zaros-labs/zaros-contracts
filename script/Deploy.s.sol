// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

// Zaros dependencies
import { BaseScript } from "./Base.s.sol";
import { Zaros } from "@zaros/core/Zaros.sol";
import { AccountNFT } from "@zaros/account-nft/AccountNFT.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract Deploy is BaseScript {
    function run() public broadcaster returns (address, address) {
        AccountNFT accountNft = new AccountNFT();
        Zaros zaros = new Zaros(address(accountNft));

        return (address(accountNft), address(zaros));
    }
}
