// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { IVerifierProxy } from "@zaros/external/chainlink/interfaces/IVerifierProxy.sol";
import { MarketOrderKeeper } from "@zaros/external/chainlink/keepers/market-order/MarketOrderKeeper.sol";
import { IPerpsEngine } from "@zaros/perpetuals/interfaces/IPerpsEngine.sol";
import { IGlobalConfigurationBranch } from "@zaros/perpetuals/interfaces/IGlobalConfigurationBranch.sol";
import { OrderFees } from "@zaros/perpetuals/leaves/OrderFees.sol";
import { SettlementConfiguration } from "@zaros/perpetuals/leaves/SettlementConfiguration.sol";
import { BaseScript } from "./Base.s.sol";
import { ProtocolConfiguration } from "script/utils/ProtocolConfiguration.sol";
import { Markets } from "script/markets/Markets.sol";
import { Base_Test } from "test/Base.t.sol";
import { MockPriceFeed } from "test/mocks/MockPriceFeed.sol";

// Open Zeppelin dependencies
import { ERC1967Proxy } from "@openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";

// Forge dependencies
import { console } from "forge-std/console.sol";

// TODO: update limit order strategies
// TODO: update owner and forwarder on keeper initialization
contract CreatePerpMarket is BaseScript, ProtocolConfiguration, Markets, Base_Test {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/
    IVerifierProxy internal chainlinkVerifier;

    /*//////////////////////////////////////////////////////////////////////////
                                    CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/
    IPerpsEngine internal zarosPerpsEngine;
    address internal zarosSettlementFeeReceiver;

    function run(uint256 INITIAL_MARKET_ID, uint256 FINAL_MARKET_ID, bool isTest) public {
        zarosPerpsEngine = IPerpsEngine(payable(address(vm.envAddress("PERPS_ENGINE"))));
        chainlinkVerifier = IVerifierProxy(vm.envAddress("CHAINLINK_VERIFIER"));
        zarosSettlementFeeReceiver = vm.envAddress("SETTLEMENT_FEE_RECEIVER");

        setupMarketsConfig();

        if (isTest) {
            createPerpMarkets(
                users.owner,
                users.settlementFeeReceiver,
                perpsEngine,
                INITIAL_MARKET_ID,
                FINAL_MARKET_ID,
                IVerifierProxy(mockChainlinkVerifier),
                true
            );
        } else {
            createPerpMarkets(
                deployer,
                zarosSettlementFeeReceiver,
                zarosPerpsEngine,
                INITIAL_MARKET_ID,
                FINAL_MARKET_ID,
                chainlinkVerifier,
                false
            );
        }
    }

    function createPerpMarkets(
        address deployer,
        address settlementFeeReceiver,
        IPerpsEngine perpsEngine,
        uint256 initialMarketId,
        uint256 finalMarketId,
        IVerifierProxy chainlinkVerifierProxy,
        bool isTest
    )
        internal
    {
        for (uint256 i = initialMarketId; i <= finalMarketId; i++) {
            address marketOrderKeeper =
                deployMarketOrderKeeper(marketsConfig[i].marketId, deployer, perpsEngine, settlementFeeReceiver);

            SettlementConfiguration.DataStreamsStrategy memory marketOrderConfigurationData = SettlementConfiguration
                .DataStreamsStrategy({ chainlinkVerifier: chainlinkVerifierProxy, streamId: marketsConfig[i].streamId });

            SettlementConfiguration.Data memory marketOrderConfiguration = SettlementConfiguration.Data({
                strategy: SettlementConfiguration.Strategy.DATA_STREAMS_ONCHAIN,
                isEnabled: true,
                fee: DEFAULT_SETTLEMENT_FEE,
                keeper: marketOrderKeeper,
                data: abi.encode(marketOrderConfigurationData)
            });

            // TODO: update to API orderbook config
            SettlementConfiguration.Data[] memory customOrderStrategies;

            perpsEngine.createPerpMarket(
                IGlobalConfigurationBranch.CreatePerpMarketParams({
                    marketId: marketsConfig[i].marketId,
                    name: marketsConfig[i].marketName,
                    symbol: marketsConfig[i].marketSymbol,
                    priceAdapter: isTest
                        ? address(new MockPriceFeed(18, int256(marketsConfig[i].mockUsdPrice)))
                        : marketsConfig[i].priceAdapter,
                    initialMarginRateX18: marketsConfig[i].imr,
                    maintenanceMarginRateX18: marketsConfig[i].mmr,
                    maxOpenInterest: marketsConfig[i].maxOi,
                    maxFundingVelocity: marketsConfig[i].maxFundingVelocity,
                    skewScale: marketsConfig[i].skewScale,
                    minTradeSizeX18: marketsConfig[i].minTradeSize,
                    marketOrderConfiguration: marketOrderConfiguration,
                    customOrderStrategies: customOrderStrategies,
                    orderFees: marketsConfig[i].orderFees
                })
            );
        }
    }

    function deployMarketOrderKeeper(
        uint128 marketId,
        address deployer,
        IPerpsEngine perpsEngine,
        address settlementFeeReceiver
    )
        internal
        returns (address marketOrderKeeper)
    {
        address marketOrderKeeperImplementation = address(new MarketOrderKeeper());

        marketOrderKeeper = address(
            new ERC1967Proxy(
                marketOrderKeeperImplementation,
                abi.encodeWithSelector(
                    MarketOrderKeeper.initialize.selector, deployer, perpsEngine, settlementFeeRecipient, marketId
                )
            )
        );

        marketOrderKeepers[marketId] = marketOrderKeeper;
    }
}
