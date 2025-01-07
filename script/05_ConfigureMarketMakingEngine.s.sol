// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.25;

// Zaros dependencies
import { RootProxy } from "@zaros/tree-proxy/RootProxy.sol";
import { IPerpsEngine } from "@zaros/perpetuals/PerpsEngine.sol";
import { IMarketMakingEngine } from "@zaros/market-making/MarketMakingEngine.sol";
import { BaseScript } from "./Base.s.sol";
import { ProtocolConfiguration } from "./utils/ProtocolConfiguration.sol";

// Forge dependencies
import { console } from "forge-std/console.sol";

contract ConfigureMarketMakingEngine is BaseScript, ProtocolConfiguration {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/
    address internal perpsEngineUsdToken;
    address internal wEth;
    address internal usdc;

    /*//////////////////////////////////////////////////////////////////////////
                                    CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/
    IPerpsEngine internal perpsEngine;
    IMarketMakingEngine internal marketMakingEngine;

    function run(uint256 initialMarginCollateralId, uint256 finalMarginCollateralId) public broadcaster {
        // setup environment variables
        marketMakingEngine = IMarketMakingEngine(vm.envAddress("MARKET_MAKING_ENGINE"));
        perpsEngine = IPerpsEngine(vm.envAddress("PERPS_ENGINE"));
        perpsEngineUsdToken = vm.envAddress("USD_TOKEN");
        wEth = vm.envAddress("WETH");
        usdc = vm.envAddress("USDC");

        console.log("**************************");
        console.log("Environment variables:");
        console.log("Market Making Engine: ", address(marketMakingEngine));
        console.log("Perps Engine: ", address(marketMakingEngine));
        console.log("Perps Engine Usd Token: ", perpsEngineUsdToken);
        console.log("wEth: ", wEth);
        console.log("USDC: ", usdc);
        console.log("**************************");

        // setup perp markets credit config
        bool isTest = false;
        RootProxy.InitParams memory mmEngineTestInitParams;
        setupPerpMarketsCreditConfig(isTest, mmEngineTestInitParams);

        console.log("**************************");
        console.log("Configuring vault deposit and redeem fee recipient...");
        console.log("**************************");

        marketMakingEngine.configureVaultDepositAndRedeemFeeRecipient(MSIG_ADDRESS);

        console.log("Success! Vault deposit and redeem fee recipient:");
        console.log("\n");
        console.log(MSIG_ADDRESS);

        console.log("**************************");
        console.log("Configuring collaterals...");
        console.log("**************************");

        // TODO

        console.log("**************************");
        console.log("Configuring system keepers...");
        console.log("**************************");

        address[] memory systemKeepers = new address[](2);
        systemKeepers[0] = address(perpsEngine);
        systemKeepers[1] = MSIG_ADDRESS;

        for(uint256 i; i < systemKeepers.length; i++) {
            marketMakingEngine.configureSystemKeeper(systemKeepers[i], true);

            console.log("Success! Configured system keeper:");
            console.log("\n");
            console.log(systemKeepers[i]);
        }

        console.log("**************************");
        console.log("Configuring engines...");
        console.log("**************************");

        address[] memory engines = new address[](1);
        engines[0] = address(perpsEngine);

        address[] memory enginesUsdToken = new address[](1);
        enginesUsdToken[0] = address(perpsEngineUsdToken);

        for(uint256 i; i < engines.length; i++) {
            marketMakingEngine.configureEngine(engines[i], enginesUsdToken[i], true);

            console.log("Success! Configured engine:");
            console.log("\n");
            console.log("Engine: ", engines[i]);
            console.log("Usd Token: ", enginesUsdToken[i]);
        }

        console.log("**************************");
        console.log("Configuring fee recipients...");
        console.log("**************************");

        marketMakingEngine.configureFeeRecipient(MSIG_ADDRESS, MSIG_SHARES_FEE_RECIPIENT);

        console.log("Success! Configured fee recipients:");
        console.log("\n");
        console.log("Fee Recipient: ", MSIG_ADDRESS);
        console.log("Shares: ", MSIG_SHARES_FEE_RECIPIENT);

        console.log("**************************");
        console.log("Configuring wEth...");
        console.log("**************************");

        marketMakingEngine.setWeth(wEth);

        console.log("Success! Configured wEth:");
        console.log("\n");
        console.log(wEth);

        console.log("**************************");
        console.log("Configuring USDC...");
        console.log("**************************");

        marketMakingEngine.setUsdc(usdc);

        console.log("Success! Configured USDC:");
        console.log("\n");
        console.log(usdc);
    }


}
