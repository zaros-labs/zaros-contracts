// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.25;

// Zaros dependencies
import { RootProxy } from "@zaros/tree-proxy/RootProxy.sol";
import { IPerpsEngine } from "@zaros/perpetuals/PerpsEngine.sol";
import { IMarketMakingEngine } from "@zaros/market-making/MarketMakingEngine.sol";
import { BaseScript } from "./Base.s.sol";
import { ProtocolConfiguration } from "script/utils/ProtocolConfiguration.sol";
import { IReferral } from "@zaros/referral/interfaces/IReferral.sol";
import { ReferralUtils } from "script/utils/ReferralUtils.sol";

// Forge dependencies
import { console } from "forge-std/console.sol";

contract ConfigureReferralModule is BaseScript, ProtocolConfiguration {
    /*//////////////////////////////////////////////////////////////////////////
                                    CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/
    IPerpsEngine internal perpsEngine;
    IMarketMakingEngine internal marketMakingEngine;
    IReferral internal referralModule;

    function run() public broadcaster {
        // setup environment variables
        marketMakingEngine = IMarketMakingEngine(vm.envAddress("MARKET_MAKING_ENGINE"));
        perpsEngine = IPerpsEngine(vm.envAddress("PERPS_ENGINE"));

        console.log("**************************");
        console.log("Environment variables:");
        console.log("Market Making Engine: ", address(marketMakingEngine));
        console.log("Perps Engine: ", address(marketMakingEngine));
        console.log("**************************");

        console.log("**************************");
        console.log("Configuring fee recipients...");
        console.log("**************************");

        referralModule = IReferral(ReferralUtils.deployReferralModule(deployer));

        referralModule.configureEngine(address(perpsEngine), true);
        referralModule.configureEngine(address(marketMakingEngine), true);

        perpsEngine.configureReferralModule(address(referralModule));
        marketMakingEngine.configureReferralModule(address(referralModule));

        console.log("Success! Configured Referral Module");
        console.log("\n");
    }
}
