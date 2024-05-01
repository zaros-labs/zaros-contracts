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
import { ProtocolConfiguration } from "./utils/ProtocolConfiguration.sol";

// Open Zeppelin dependencies
import { ERC1967Proxy } from "@openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";

// Forge dependencies
import { console } from "forge-std/console.sol";

// TODO: update limit order strategies
// TODO: update owner and forwarder on keeper initialization
contract CreatePerpMarket is BaseScript, ProtocolConfiguration {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/
    IVerifierProxy internal chainlinkVerifier;

    /*//////////////////////////////////////////////////////////////////////////
                                    CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/
    IPerpsEngine internal perpsEngine;
    address internal settlementFeeRecipient;

    function run(uint256 INITIAL_MARKET_ID, uint256 FINAL_MARKET_ID) public broadcaster {
        perpsEngine = IPerpsEngine(payable(address(vm.envAddress("PERPS_ENGINE"))));
        chainlinkVerifier = IVerifierProxy(vm.envAddress("CHAINLINK_VERIFIER"));
        settlementFeeRecipient = vm.envAddress("SETTLEMENT_FEE_RECEIVER");

        uint256[2] memory marketsIdsRange;
        marketsIdsRange[0] = INITIAL_MARKET_ID;
        marketsIdsRange[1] = FINAL_MARKET_ID;

        MarketConfig[] memory filteredMarketsConfig = getFilteredMarketsConfig(marketsIdsRange);

        for (uint256 i = 0; i < filteredMarketsConfig.length; i++) {
            SettlementConfiguration.DataStreamsStrategy memory marketOrderConfigurationData = SettlementConfiguration
                .DataStreamsStrategy({ chainlinkVerifier: chainlinkVerifier, streamId: filteredMarketsConfig[i].streamId });

            address marketOrderKeeperImplementation = address(new MarketOrderKeeper());
            console.log("MarketOrderKeeper Implementation: ", marketOrderKeeperImplementation);
            address marketOrderKeeper =
                deployMarketOrderKeeper(filteredMarketsConfig[i].marketId, marketOrderKeeperImplementation);

            SettlementConfiguration.Data memory marketOrderConfiguration = SettlementConfiguration.Data({
                strategy: SettlementConfiguration.Strategy.DATA_STREAMS_ONCHAIN,
                isEnabled: true,
                fee: DEFAULT_SETTLEMENT_FEE,
                keeper: marketOrderKeeper,
                data: abi.encode(marketOrderConfigurationData)
            });

            // TODO: configure custom orders and set the API's keeper
            SettlementConfiguration.Data[] memory customOrdersConfigurations;

            perpsEngine.createPerpMarket({
                params: IGlobalConfigurationBranch.CreatePerpMarketParams({
                    marketId: filteredMarketsConfig[i].marketId,
                    name: filteredMarketsConfig[i].marketName,
                    symbol: filteredMarketsConfig[i].marketSymbol,
                    priceAdapter: filteredMarketsConfig[i].priceAdapter,
                    initialMarginRateX18: filteredMarketsConfig[i].imr,
                    maintenanceMarginRateX18: filteredMarketsConfig[i].mmr,
                    maxOpenInterest: filteredMarketsConfig[i].maxOi,
                    skewScale: filteredMarketsConfig[i].skewScale,
                    minTradeSizeX18: filteredMarketsConfig[i].minTradeSize,
                    maxFundingVelocity: filteredMarketsConfig[i].maxFundingVelocity,
                    marketOrderConfiguration: marketOrderConfiguration,
                    customOrderStrategies: customOrdersConfigurations,
                    orderFees: filteredMarketsConfig[i].orderFees
                })
            });
        }
    }

    function deployMarketOrderKeeper(
        uint128 marketId,
        address marketOrderKeeperImplementation
    )
        internal
        returns (address marketOrderKeeper)
    {
        marketOrderKeeper = address(
            new ERC1967Proxy(
                marketOrderKeeperImplementation,
                abi.encodeWithSelector(
                    MarketOrderKeeper.initialize.selector, deployer, perpsEngine, settlementFeeRecipient, marketId
                )
            )
        );
    }
}
