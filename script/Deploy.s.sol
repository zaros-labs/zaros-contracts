// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

// Zaros dependencies
import { BaseScript } from "./Base.s.sol";
import { AccountNFT } from "@zaros/account-nft/AccountNFT.sol";
import { Zaros } from "@zaros/core/Zaros.sol";
import { ZarosUSD } from "@zaros/usd/ZarosUSD.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract Deploy is BaseScript {
    function run() public broadcaster returns (address, address) {
        AccountNFT accountNft = new AccountNFT();
            ZarosUSD zrsUsd = new ZarosUSD();
        Zaros zaros = new Zaros(address(accountNft), address(zrsUsd));

        return (address(accountNft), address(zaros));
    }
}
