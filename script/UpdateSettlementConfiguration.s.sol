// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { IVerifierProxy } from "@zaros/external/chainlink/interfaces/IVerifierProxy.sol";
import { IPerpsEngine } from "@zaros/markets/perps/interfaces/IPerpsEngine.sol";
import { SettlementConfiguration } from "@zaros/markets/perps/storage/SettlementConfiguration.sol";
import { BaseScript } from "./Base.s.sol";
import { ProtocolConfiguration } from "./utils/ProtocolConfiguration.sol";

// Open Zeppelin dependencies
import { ERC1967Proxy } from "@openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
import { UUPSUpgradeable } from "@openzeppelin/proxy/utils/UUPSUpgradeable.sol";

// Forge dependencies
import { console } from "forge-std/console.sol";

contract UpdateSettlementConfiguration is BaseScript, ProtocolConfiguration {
    /*//////////////////////////////////////////////////////////////////////////
                                    VARIABLES
    //////////////////////////////////////////////////////////////////////////*/
    string internal ethUsdStreamId;

    /*//////////////////////////////////////////////////////////////////////////
                                    CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/
    IVerifierProxy internal chainlinkVerifier;
    address internal ethUsdMarketOrderKeeper;
    IPerpsEngine internal perpsEngine;

    function run() public broadcaster {
        perpsEngine = IPerpsEngine(vm.envAddress("PERPS_ENGINE"));
        ethUsdStreamId = vm.envString("ETH_USD_STREAM_ID");
        chainlinkVerifier = IVerifierProxy(vm.envAddress("CHAINLINK_VERIFIER"));
        ethUsdMarketOrderKeeper = vm.envAddress("ETH_USD_MARKET_ORDER_KEEPER");

        SettlementConfiguration.DataStreamsMarketStrategy memory ethUsdMarketOrderConfigurationData =
        SettlementConfiguration.DataStreamsMarketStrategy({
            chainlinkVerifier: chainlinkVerifier,
            streamId: ethUsdStreamId,
            feedLabel: DATA_STREAMS_FEED_PARAM_KEY,
            queryLabel: DATA_STREAMS_TIME_PARAM_KEY,
            settlementDelay: ETH_USD_SETTLEMENT_DELAY,
            isPremium: ETH_USD_IS_PREMIUM_FEED
        });
        SettlementConfiguration.Data memory ethUsdMarketOrderConfiguration = SettlementConfiguration.Data({
            strategy: SettlementConfiguration.Strategy.DATA_STREAMS_MARKET,
            isEnabled: true,
            fee: DEFAULT_SETTLEMENT_FEE,
            keeper: ethUsdMarketOrderKeeper,
            data: abi.encode(ethUsdMarketOrderConfigurationData)
        });

        perpsEngine.updateSettlementConfiguration(
            ETH_USD_MARKET_ID, SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID, ethUsdMarketOrderConfiguration
        );
    }
}
