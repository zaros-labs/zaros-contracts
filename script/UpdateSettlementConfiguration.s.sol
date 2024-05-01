// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.25;

// Zaros dependencies
import { IVerifierProxy } from "@zaros/external/chainlink/interfaces/IVerifierProxy.sol";
import { IPerpsEngine } from "@zaros/perpetuals/interfaces/IPerpsEngine.sol";
import { SettlementConfiguration } from "@zaros/perpetuals/leaves/SettlementConfiguration.sol";
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
    bytes32 internal ethUsdStreamId;

    /*//////////////////////////////////////////////////////////////////////////
                                    CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/
    IVerifierProxy internal chainlinkVerifier;
    address internal ethUsdMarketOrderKeeper;
    IPerpsEngine internal perpsEngine;

    function run() public broadcaster {
        perpsEngine = IPerpsEngine(vm.envAddress("PERPS_ENGINE"));
        ethUsdStreamId = vm.envBytes32("ETH_USD_STREAM_ID");
        chainlinkVerifier = IVerifierProxy(vm.envAddress("CHAINLINK_VERIFIER"));
        ethUsdMarketOrderKeeper = vm.envAddress("ETH_USD_MARKET_ORDER_KEEPER");

        SettlementConfiguration.DataStreamsStrategy memory ethUsdMarketOrderConfigurationData =
        SettlementConfiguration.DataStreamsStrategy({ chainlinkVerifier: chainlinkVerifier, streamId: ethUsdStreamId });
        SettlementConfiguration.Data memory ethUsdMarketOrderConfiguration = SettlementConfiguration.Data({
            strategy: SettlementConfiguration.Strategy.DATA_STREAMS_ONCHAIN,
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
