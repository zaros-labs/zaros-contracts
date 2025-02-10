// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.25;

// Zaros dependencies
import { IVerifierProxy } from "@zaros/external/chainlink/interfaces/IVerifierProxy.sol";
import { IPerpsEngine } from "@zaros/perpetuals/PerpsEngine.sol";
import { IMarketMakingEngine } from "@zaros/market-making/MarketMakingEngine.sol";
import { BaseScript } from "./Base.s.sol";
import { ProtocolConfiguration } from "script/utils/ProtocolConfiguration.sol";
import { LimitedMintingERC20 } from "testnet/LimitedMintingERC20.sol";
import { IFeeManager } from "@zaros/external/chainlink/interfaces/IFeeManager.sol";
import { MockChainlinkFeeManager } from "test/mocks/MockChainlinkFeeManager.sol";
import { MockChainlinkVerifier } from "test/mocks/MockChainlinkVerifier.sol";

// Forge dependencies
import { console } from "forge-std/console.sol";

// Open Zeppelin Upgradeable dependencies
import { IERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";

contract ConfigureMarketMakingEngine is BaseScript, ProtocolConfiguration {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/
    address internal chainlinkVerifier;
    address internal perpsEngineUsdToken;
    address internal wEth;
    address internal usdc;

    /*//////////////////////////////////////////////////////////////////////////
                                    CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/
    IPerpsEngine internal perpsEngine;
    IMarketMakingEngine internal marketMakingEngine;

    function run(
        uint256 initialMarginCollateralId,
        uint256 finalMarginCollateralId,
        bool useMockChainlinkVerifier
    )
        public
        broadcaster
    {
        // setup environment variables
        marketMakingEngine = IMarketMakingEngine(vm.envAddress("MARKET_MAKING_ENGINE"));
        perpsEngine = IPerpsEngine(vm.envAddress("PERPS_ENGINE"));
        perpsEngineUsdToken = vm.envAddress("USD_TOKEN");
        chainlinkVerifier = vm.envAddress("CHAINLINK_VERIFIER");
        wEth = vm.envAddress("WETH");
        usdc = vm.envAddress("USDC");

        console.log("**************************");
        console.log("Environment variables:");
        console.log("Market Making Engine: ", address(marketMakingEngine));
        console.log("Perps Engine: ", address(marketMakingEngine));
        console.log("Perps Engine Usd Token: ", perpsEngineUsdToken);
        console.log("Chainlink Verifier: ", address(chainlinkVerifier));
        console.log("wEth: ", wEth);
        console.log("USDC: ", usdc);
        console.log("CONSTANTS:");
        console.log("MSIG_ADDRESS: ", MSIG_ADDRESS);
        console.log("MSIG_SHARES_FEE_RECIPIENT: ", MSIG_SHARES_FEE_RECIPIENT);
        console.log("MAX_VERIFICATION_DELAY: ", MAX_VERIFICATION_DELAY);
        console.log("INITIAL_MARKET_MAKING_ENGINE_COLLATERAL_ID: ", INITIAL_MARKET_MAKING_ENGINE_COLLATERAL_ID);
        console.log("FINAL_MARKET_MAKING_ENGINE_COLLATERAL_ID: ", FINAL_MARKET_MAKING_ENGINE_COLLATERAL_ID);
        console.log("INITIAL_PERP_MARKET_CREDIT_CONFIG_ID: ", INITIAL_PERP_MARKET_CREDIT_CONFIG_ID);
        console.log("FINAL_PERP_MARKET_CREDIT_CONFIG_ID: ", FINAL_PERP_MARKET_CREDIT_CONFIG_ID);
        console.log("**************************");

        // setup perp markets credit config
        bool isTest = false;
        setupPerpMarketsCreditConfig(isTest, address(perpsEngine), perpsEngineUsdToken);

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

        setupMarketMakingEngineCollaterals();
        uint256[2] memory marketMakingEngineCollateralIdsRange;
        marketMakingEngineCollateralIdsRange[0] = INITIAL_MARKET_MAKING_ENGINE_COLLATERAL_ID;
        marketMakingEngineCollateralIdsRange[1] = FINAL_MARKET_MAKING_ENGINE_COLLATERAL_ID;
        configureMarketMakingEngineCollaterals(marketMakingEngine, marketMakingEngineCollateralIdsRange);

        console.log("**************************");
        console.log("Configuring system keepers...");
        console.log("**************************");

        address[] memory systemKeepers = new address[](2);
        systemKeepers[0] = address(perpsEngine);
        systemKeepers[1] = MSIG_ADDRESS;

        for (uint256 i; i < systemKeepers.length; i++) {
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

        for (uint256 i; i < engines.length; i++) {
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

        console.log("**************************");
        console.log("Transferring USD Token ownership to the market making engine...");
        console.log("**************************");

        // NOTE: Once the MM engine v1 is deployed, USD Token ownership must be transferred to the MM engine.
        LimitedMintingERC20(USD_TOKEN_ADDRESS).transferOwnership(address(marketMakingEngine));

        console.log("Success! USD Token token ownership transferred to the market making engine.");
        console.log("\n");

        console.log("**************************");
        console.log("Configuring Market Making Engine allowance...");
        console.log("**************************");

        uint256[2] memory marginCollateralIdsRange;
        marginCollateralIdsRange[0] = initialMarginCollateralId;
        marginCollateralIdsRange[1] = finalMarginCollateralId;

        configureMarginCollaterals(
            perpsEngine, marginCollateralIdsRange, false, sequencerUptimeFeedByChainId[block.chainid], deployer
        );

        uint256 totalOfMarginCollaterals = finalMarginCollateralId - initialMarginCollateralId + 1;
        IERC20[] memory marginCollateralsArray = new IERC20[](totalOfMarginCollaterals);
        uint256[] memory allowances = new uint256[](totalOfMarginCollaterals);
        for (uint256 i = initialMarginCollateralId; i <= finalMarginCollateralId; i++) {
            marginCollateralsArray[i - 1] = IERC20(marginCollaterals[i].marginCollateralAddress);
            allowances[i - 1] = type(uint256).max;
        }

        perpsEngine.setMarketMakingEngineAllowance(marginCollateralsArray, allowances);

        console.log("Success! Configured Market Making Engine allowance");
        console.log("\n");

        console.log("**************************");
        console.log("Configuring Market Making Engine Stability Configuration...");
        console.log("**************************");

        if (useMockChainlinkVerifier) {
            address mockChainlinkFeeManager = address(new MockChainlinkFeeManager());
            chainlinkVerifier = address(new MockChainlinkVerifier(IFeeManager(mockChainlinkFeeManager)));

            console.log("useMockChainlinkVerifier: true");
        }

        marketMakingEngine.updateStabilityConfiguration(chainlinkVerifier, uint128(MAX_VERIFICATION_DELAY));

        console.log("Success! Configured Market Making Engine Stability Configuration");
        console.log("\n");

        console.log("**************************");
        console.log("Configuring Markets...");
        console.log("**************************");

        configureMarkets(
            ConfigureMarketParams({
                marketMakingEngine: marketMakingEngine,
                initialMarketId: INITIAL_PERP_MARKET_CREDIT_CONFIG_ID,
                finalMarketId: FINAL_PERP_MARKET_CREDIT_CONFIG_ID
            })
        );

        console.log("Success! Configured Markets");
        console.log("\n");
    }
}
