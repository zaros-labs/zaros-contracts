// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

// Zaros dependencies
import { TradingAccountNFT } from "@zaros/trading-account-nft/TradingAccountNFT.sol";
import { IPerpsEngine } from "@zaros/perpetuals/PerpsEngine.sol";
import { IMarketMakingEngine } from "@zaros/market-making/MarketMakingEngine.sol";
import { BaseScript } from "./Base.s.sol";
import { ProtocolConfiguration } from "./utils/ProtocolConfiguration.sol";
import { IReferral } from "@zaros/referral/interfaces/IReferral.sol";

// Forge dependencies
import { console } from "forge-std/console.sol";

contract ConfigurePerpsEngine is BaseScript, ProtocolConfiguration {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/
    address internal usdToken;
    address internal liquidationKeeper;

    /*//////////////////////////////////////////////////////////////////////////
                                    CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/
    TradingAccountNFT internal tradingAccountToken;
    IPerpsEngine internal perpsEngine;
    IMarketMakingEngine internal marketMakingEngine;
    IReferral internal referralModule;

    function run(uint256 initialMarginCollateralId, uint256 finalMarginCollateralId) public broadcaster {
        tradingAccountToken = TradingAccountNFT(vm.envAddress("TRADING_ACCOUNT_NFT"));
        perpsEngine = IPerpsEngine(vm.envAddress("PERPS_ENGINE"));
        marketMakingEngine = IMarketMakingEngine(vm.envAddress("MARKET_MAKING_ENGINE"));
        usdToken = vm.envAddress("USD_TOKEN");
        liquidationKeeper = vm.envAddress("LIQUIDATION_KEEPER");
        referralModule = IReferral(vm.envAddress("REFERRAL_MODULE"));

        console.log("**************************");
        console.log("Environment variables:");
        console.log("Trading Account Token: ", address(tradingAccountToken));
        console.log("Perps Engine: ", address(perpsEngine));
        console.log("Market Making Engine: ", address(marketMakingEngine));
        console.log("Usd Token: ", usdToken);
        console.log("Liquidation Keeper: ", liquidationKeeper);
        console.log("Referral Module: ", address(referralModule));
        console.log("**************************");

        configureContracts(initialMarginCollateralId, finalMarginCollateralId);
    }

    function configureContracts(uint256 initialMarginCollateralId, uint256 finalMarginCollateralId) internal {
        perpsEngine.configureSystemParameters({
            maxPositionsPerAccount: MAX_POSITIONS_PER_ACCOUNT,
            marketOrderMinLifetime: MARKET_ORDER_MIN_LIFETIME,
            liquidationFeeUsdX18: LIQUIDATION_FEE_USD,
            marketMakingEngine: address(marketMakingEngine),
            referralModule: address(referralModule),
            whitelist: address(0),
            maxVerificationDelay: MAX_VERIFICATION_DELAY,
            isWhitelistMode: false
        });

        setupSequencerUptimeFeeds();

        uint256[2] memory marginCollateralIdsRange;
        marginCollateralIdsRange[0] = initialMarginCollateralId;
        marginCollateralIdsRange[1] = finalMarginCollateralId;

        configureMarginCollaterals(
            perpsEngine, marginCollateralIdsRange, false, sequencerUptimeFeedByChainId[block.chainid], deployer
        );

        address[] memory liquidators = new address[](1);
        bool[] memory liquidatorStatus = new bool[](1);

        liquidators[0] = liquidationKeeper;
        liquidatorStatus[0] = true;

        console.log("**************************");
        console.log("Configuring liquidators...");
        console.log("**************************");

        perpsEngine.configureLiquidators(liquidators, liquidatorStatus);

        console.log("Success! Liquidator address:");
        console.log(liquidators[0]);

        console.log("**************************");
        console.log("Configuring USD Token token...");
        console.log("**************************");

        perpsEngine.setUsdToken(usdToken);

        console.log("Success! USD Token token address:");
        console.log(usdToken);

        console.log("**************************");
        console.log("Configuring trading account token...");
        console.log("**************************");

        perpsEngine.setTradingAccountToken(address(tradingAccountToken));

        console.log("Success! Trading account token address:");
        console.log(address(tradingAccountToken));

        console.log("**************************");
        console.log("Transferring Trading Account Token ownership to the perps engine...");
        console.log("**************************");

        tradingAccountToken.transferOwnership(address(perpsEngine));

        console.log("Success! Trading Account Token token ownership transferred to the perps engine.");
    }
}
