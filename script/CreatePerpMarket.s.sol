// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { IVerifierProxy } from "@zaros/external/chainlink/interfaces/IVerifierProxy.sol";
import { MarketOrderKeeper } from "@zaros/external/chainlink/keepers/market-order/MarketOrderKeeper.sol";
import { IPerpsEngine } from "@zaros/markets/perps/interfaces/IPerpsEngine.sol";
import { IGlobalConfigurationModule } from "@zaros/markets/perps/interfaces/IGlobalConfigurationModule.sol";
import { OrderFees } from "@zaros/markets/perps/storage/OrderFees.sol";
import { SettlementConfiguration } from "@zaros/markets/perps/storage/SettlementConfiguration.sol";
import { BaseScript } from "./Base.s.sol";
import { ProtocolConfiguration } from "./utils/ProtocolConfiguration.sol";
import { Markets } from "script/markets/Markets.sol";

// Open Zeppelin dependencies
import { ERC1967Proxy } from "@openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";

// Forge dependencies
import { console } from "forge-std/console.sol";

// TODO: update limit order strategies
// TODO: update owner and forwarder on keeper initialization
contract CreatePerpMarket is BaseScript, ProtocolConfiguration, Markets {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/
    IVerifierProxy internal chainlinkVerifier;

    /*//////////////////////////////////////////////////////////////////////////
                                    CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/
    IPerpsEngine internal perpsEngine;
    address internal settlementFeeReceiver;

    function run(uint256 initialMarketIndex, uint256 finalMarketIndex) public broadcaster {
        perpsEngine = IPerpsEngine(payable(address(vm.envAddress("PERPS_ENGINE"))));
        chainlinkVerifier = IVerifierProxy(vm.envAddress("CHAINLINK_VERIFIER"));
        settlementFeeReceiver = vm.envAddress("SETTLEMENT_FEE_RECEIVER");

        uint256[] memory filteredIndexMarkets = new uint256[](2);
        filteredIndexMarkets[0] = initialMarketIndex;
        filteredIndexMarkets[1] = finalMarketIndex;

        (MarketConfig[] memory marketsConfig) = getMarketsConfig(filteredIndexMarkets);

        createPerpMarkets(
            deployer,
            settlementFeeReceiver,
            perpsEngine,
            marketsConfig,
            IVerifierProxy(vm.envAddress("CHAINLINK_VERIFIER")),
            false
        );

        for (uint256 i = 0; i < marketsConfig.length; i++) {
            console.log("MarketOrderKeeper Implementation: ", marketOrderKeepers[marketsConfig[i].marketId]);
        }
    }
}
