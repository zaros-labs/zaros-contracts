// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { PerpMarket } from "@zaros/perpetuals/leaves/PerpMarket.sol";
import { MarketConfiguration } from "@zaros/perpetuals/leaves/MarketConfiguration.sol";
import { OrderFees } from "@zaros/perpetuals/leaves/OrderFees.sol";

contract MarketConfigurationHarness {
    function exposed_update(
        uint128 marketId,
        string memory name,
        string memory symbol,
        address priceAdapter,
        uint128 initialMarginRateX18,
        uint128 maintenanceMarginRateX18,
        uint128 maxOpenInterest,
        uint128 maxSkew,
        uint128 maxFundingVelocity,
        uint128 minTradeSizeX18,
        uint256 skewScale,
        OrderFees.Data memory orderFees
    )
        external
    {
        PerpMarket.Data storage perpMarket = PerpMarket.load(marketId);
        MarketConfiguration.Data storage self = perpMarket.configuration;

        MarketConfiguration.update(
            self,
            name,
            symbol,
            priceAdapter,
            initialMarginRateX18,
            maintenanceMarginRateX18,
            maxOpenInterest,
            maxSkew,
            maxFundingVelocity,
            minTradeSizeX18,
            skewScale,
            orderFees
        );
    }
}
