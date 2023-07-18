// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

// Zaros dependencies
import { BaseScript } from "../Base.s.sol";
import { MockERC20 } from "../../test/mocks/MockERC20.sol";
import { MockZarosUSD } from "../../test/mocks/MockZarosUSD.sol";
import { AccountNFT } from "@zaros/account-nft/AccountNFT.sol";
import { Zaros } from "@zaros/core/Zaros.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract DeployMockedZaros is BaseScript {
    function run() public broadcaster {
        MockERC20 sFrxEth = new MockERC20("Staked Frax Ether", "sfrxETH", 18);
        MockERC20 usdc = new MockERC20("USD Coin", "USDC", 6);
        MockZarosUSD zrsUsd = new MockZarosUSD(100_000_000e18);
        AccountNFT accountNft = new AccountNFT();
        Zaros zaros = new Zaros(address(accountNft), address(zrsUsd));

        sFrxEth.mint(deployer, 100_000_000e18);
        usdc.mint(deployer, 100_000_000e6);
    }
}
