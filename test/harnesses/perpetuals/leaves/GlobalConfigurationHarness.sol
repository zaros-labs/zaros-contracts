// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { GlobalConfiguration } from "@zaros/perpetuals/leaves/GlobalConfiguration.sol";

contract GlobalConfigurationHarness {
    function exposed_checkMarketIsEnabled(uint128 marketId) external view {
        GlobalConfiguration.Data storage self = GlobalConfiguration.load();
        GlobalConfiguration.checkMarketIsEnabled(self, marketId);
    }

    function exposed_addMarket(uint128 marketId) external {
        GlobalConfiguration.Data storage self = GlobalConfiguration.load();
        GlobalConfiguration.addMarket(self, marketId);
    }

    function exposed_removeMarket(uint128 marketId) external {
        GlobalConfiguration.Data storage self = GlobalConfiguration.load();
        GlobalConfiguration.removeMarket(self, marketId);
    }

    function exposed_configureCollateralLiquidationPriority(address[] memory collateralTokens) external {
        GlobalConfiguration.Data storage self = GlobalConfiguration.load();
        GlobalConfiguration.configureCollateralLiquidationPriority(self, collateralTokens);
    }

    function exposed_removeCollateralFromLiquidationPriority(address collateralToken) external {
        GlobalConfiguration.Data storage self = GlobalConfiguration.load();
        GlobalConfiguration.removeCollateralFromLiquidationPriority(self, collateralToken);
    }
}
