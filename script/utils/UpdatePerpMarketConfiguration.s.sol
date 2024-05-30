// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.25;

// Zaros dependencies
import { IVerifierProxy } from "@zaros/external/chainlink/interfaces/IVerifierProxy.sol";
import { IPerpsEngine } from "@zaros/perpetuals/PerpsEngine.sol";
import { SettlementConfiguration } from "@zaros/perpetuals/leaves/SettlementConfiguration.sol";
import { BaseScript } from "script/Base.s.sol";
import { ProtocolConfiguration } from "script/utils/ProtocolConfiguration.sol";
import { GlobalConfigurationBranch } from "@zaros/perpetuals/branches/GlobalConfigurationBranch.sol";

// Open Zeppelin dependencies
import { ERC1967Proxy } from "@openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
import { UUPSUpgradeable } from "@openzeppelin/proxy/utils/UUPSUpgradeable.sol";

// Forge dependencies
import { console } from "forge-std/console.sol";

contract UpdatePerpMarketConfiguration is BaseScript, ProtocolConfiguration {
    /*//////////////////////////////////////////////////////////////////////////
                                    VARIABLES
    //////////////////////////////////////////////////////////////////////////*/
    bytes32 internal solUsdStreamId;

    /*//////////////////////////////////////////////////////////////////////////
                                    CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/
    IVerifierProxy internal chainlinkVerifier;
    address internal solUsdMarketOrderKeeper;
    IPerpsEngine internal perpsEngine;

    function run(uint128 marketId) public broadcaster {
        perpsEngine = IPerpsEngine(vm.envAddress("PERPS_ENGINE"));

        setupMarketsConfig();

        GlobalConfigurationBranch.UpdatePerpMarketConfigurationParams memory params = GlobalConfigurationBranch
            .UpdatePerpMarketConfigurationParams({
            marketId: marketId,
            name: marketsConfig[marketId].marketName,
            symbol: marketsConfig[marketId].marketSymbol,
            priceAdapter: marketsConfig[marketId].priceAdapter,
            initialMarginRateX18: marketsConfig[marketId].imr,
            maintenanceMarginRateX18: marketsConfig[marketId].mmr,
            maxOpenInterest: marketsConfig[marketId].maxOi,
            maxSkew: marketsConfig[marketId].maxSkew,
            maxFundingVelocity: marketsConfig[marketId].maxFundingVelocity,
            minTradeSizeX18: marketsConfig[marketId].minTradeSize,
            skewScale: marketsConfig[marketId].skewScale,
            orderFees: marketsConfig[marketId].orderFees
        });

        perpsEngine.updatePerpMarketConfiguration(params);
    }
}


