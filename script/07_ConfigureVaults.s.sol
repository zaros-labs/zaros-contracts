// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.25;

// Zaros dependencies
import { IMarketMakingEngine } from "@zaros/market-making/MarketMakingEngine.sol";
import { BaseScript } from "./Base.s.sol";
import { ProtocolConfiguration } from "script/utils/ProtocolConfiguration.sol";

// Forge dependencies
import { console } from "forge-std/console.sol";

contract ConfigureMarketMakingEngine is BaseScript, ProtocolConfiguration {
    /*//////////////////////////////////////////////////////////////////////////
                                    CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/
    IMarketMakingEngine internal marketMakingEngine;

    function run(uint256 initialVaultId, uint256 finalVaultId) public broadcaster {
        // setup environment variables
        marketMakingEngine = IMarketMakingEngine(vm.envAddress("MARKET_MAKING_ENGINE"));

        console.log("**************************");
        console.log("Environment variables:");
        console.log("Market Making Engine: ", address(marketMakingEngine));
        console.log("CONSTANTS:");
        console.log("INITIAL_PERP_MARKET_CREDIT_CONFIG_ID: ", INITIAL_PERP_MARKET_CREDIT_CONFIG_ID);
        console.log("FINAL_PERP_MARKET_CREDIT_CONFIG_ID: ", FINAL_PERP_MARKET_CREDIT_CONFIG_ID);
        console.log("**************************");

        // Vault and markets setup
        uint256[2] memory vaultsIdsRange;
        vaultsIdsRange[0] = initialVaultId;
        vaultsIdsRange[1] = finalVaultId;

        uint256[] memory perpMarketsCreditConfigIds =
            new uint256[](FINAL_PERP_MARKET_CREDIT_CONFIG_ID - INITIAL_PERP_MARKET_CREDIT_CONFIG_ID + 1);
        uint256 arrayIndex = 0;
        for (uint256 i = INITIAL_PERP_MARKET_CREDIT_CONFIG_ID; i <= FINAL_PERP_MARKET_CREDIT_CONFIG_ID; i++) {
            perpMarketsCreditConfigIds[arrayIndex++] = i;
        }

        uint256[] memory vaultIds = new uint256[](FINAL_VAULT_ID - INITIAL_VAULT_ID + 1);
        arrayIndex = 0;
        for (uint256 i = initialVaultId; i <= finalVaultId; i++) {
            vaultIds[arrayIndex++] = i;
        }

        console.log("**************************");
        console.log("Configuring Vaults...");
        console.log("**************************");

        setupVaultsConfig();

        createZlpVaults(address(marketMakingEngine), deployer, vaultsIdsRange);

        createVaults(marketMakingEngine, initialVaultId, finalVaultId, false, address(0));

        marketMakingEngine.connectVaultsAndMarkets(perpMarketsCreditConfigIds, vaultIds);

        console.log("Success! Vaults configured.");
        console.log("\n");
    }
}
