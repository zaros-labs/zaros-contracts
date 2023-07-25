// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

// Zaros dependencies
import { Constants } from "@zaros/utils/Constants.sol";
import { BaseScript } from "../Base.s.sol";
import { MockERC20 } from "../../test/mocks/MockERC20.sol";
import { MockZarosUSD } from "../../test/mocks/MockZarosUSD.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract DeployMockTokens is BaseScript {
    function run() public broadcaster returns (MockERC20, MockERC20, MockZarosUSD) {
        MockERC20 sFrxEth = new MockERC20("Staked Frax Ether", "sfrxETH", 18);
        MockERC20 usdc = new MockERC20("USD Coin", "USDC", 6);
        MockZarosUSD zrsUsd = new MockZarosUSD(1_000_000_000e18);

        sFrxEth.mint(deployer, 1_000_000_000e18);
        usdc.mint(deployer, 1_000_000_000e6);

        zrsUsd.addToFeatureFlagAllowlist(Constants.MINT_FEATURE_FLAG, vm.envAddress("ZAROS"));
        zrsUsd.addToFeatureFlagAllowlist(Constants.BURN_FEATURE_FLAG, vm.envAddress("ZAROS"));

        return (sFrxEth, usdc, zrsUsd);
    }
}
