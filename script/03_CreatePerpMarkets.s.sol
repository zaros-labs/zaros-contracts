// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { IVerifierProxy } from "@zaros/external/chainlink/interfaces/IVerifierProxy.sol";
import { MarketOrderKeeper } from "@zaros/external/chainlink/keepers/market-order/MarketOrderKeeper.sol";
import { IPerpsEngine } from "@zaros/perpetuals/PerpsEngine.sol";
import { GlobalConfigurationBranch } from "@zaros/perpetuals/branches/GlobalConfigurationBranch.sol";
import { OrderFees } from "@zaros/perpetuals/leaves/OrderFees.sol";
import { SettlementConfiguration } from "@zaros/perpetuals/leaves/SettlementConfiguration.sol";
import { BaseScript } from "./Base.s.sol";
import { ProtocolConfiguration } from "./utils/ProtocolConfiguration.sol";
import { AutomationHelpers } from "script/helpers/AutomationHelpers.sol";

// Open Zeppelin dependencies
import { ERC1967Proxy } from "@openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";

// Forge dependencies
import { console } from "forge-std/console.sol";

contract CreatePerpMarkets is BaseScript, ProtocolConfiguration {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/
    IVerifierProxy internal chainlinkVerifier;
    uint256 internal keeperInitialLinkFunding;

    /*//////////////////////////////////////////////////////////////////////////
                                    CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/
    IPerpsEngine internal perpsEngine;
    address internal settlementFeeRecipient;
    address internal registerUpkeep;

    function run(uint256 initialMarketId, uint256 finalMarketId) public broadcaster {
        perpsEngine = IPerpsEngine(payable(address(vm.envAddress("PERPS_ENGINE"))));
        chainlinkVerifier = IVerifierProxy(vm.envAddress("CHAINLINK_VERIFIER"));
        registerUpkeep = vm.envAddress("REGISTER_UPKEEP");
        keeperInitialLinkFunding = vm.envUint("KEEPER_INITIAL_LINK_FUNDING");
        settlementFeeRecipient = MSIG_ADDRESS;

        uint256[2] memory marketsIdsRange;
        marketsIdsRange[0] = initialMarketId;
        marketsIdsRange[1] = finalMarketId;

        setupMarketsConfig();

        MarketConfig[] memory filteredMarketsConfig = getFilteredMarketsConfig(marketsIdsRange);

        address marketOrderKeeperImplementation = address(new MarketOrderKeeper());
        console.log("MarketOrderKeeper Implementation: ", marketOrderKeeperImplementation);

        for (uint256 i = 0; i < filteredMarketsConfig.length; i++) {
            SettlementConfiguration.DataStreamsStrategy memory marketOrderConfigurationData = SettlementConfiguration
                .DataStreamsStrategy({ chainlinkVerifier: chainlinkVerifier, streamId: filteredMarketsConfig[i].streamId });

            address marketOrderKeeper = deployMarketOrderKeeper(
                filteredMarketsConfig[i].marketId,
                deployer,
                perpsEngine,
                settlementFeeRecipient,
                marketOrderKeeperImplementation
            );

            console.log(
                "Market Order Keeper Deployed: Market ID: ",
                filteredMarketsConfig[i].marketId,
                " Keeper Address: ",
                marketOrderKeeper
            );

            AutomationHelpers.registerMarketOrderKeeper({
                name: filteredMarketsConfig[i].marketName,
                marketOrderKeeper: marketOrderKeeper,
                registerUpkeep: registerUpkeep,
                adminAddress: MSIG_ADDRESS,
                linkAmount: keeperInitialLinkFunding
            });

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
                params: GlobalConfigurationBranch.CreatePerpMarketParams({
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
                    customOrdersConfiguration: customOrdersConfigurations,
                    orderFees: filteredMarketsConfig[i].orderFees
                })
            });
        }
    }

    function deployMarketOrderKeeper(
        uint128 marketId,
        string memory streamIdString,
        address marketOrderKeeperImplementation
    )
        internal
        returns (address marketOrderKeeper)
    {
        marketOrderKeeper = address(
            new ERC1967Proxy(
                marketOrderKeeperImplementation,
                abi.encodeWithSelector(
                    MarketOrderKeeper.initialize.selector,
                    deployer,
                    perpsEngine,
                    settlementFeeRecipient,
                    marketId,
                    streamIdString
                )
            )
        );
    }
}
