// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { OrderFees } from "./OrderFees.sol";

library MarketConfiguration {
    struct Data {
        string name;
        string symbol;
        address priceAdapter;
        uint128 minInitialMarginRateX18;
        uint128 maintenanceMarginRateX18;
        uint128 maxOpenInterest;
        uint128 maxFundingVelocity;
        uint256 skewScale;
        OrderFees.Data orderFees;
    }

    function update(
        Data storage self,
        string memory name,
        string memory symbol,
        address priceAdapter,
        uint128 minInitialMarginRateX18,
        uint128 maintenanceMarginRateX18,
        uint128 maxOpenInterest,
        uint128 maxFundingVelocity,
        uint256 skewScale,
        OrderFees.Data memory orderFees
    )
        internal
    {
        self.name = name;
        self.symbol = symbol;
        self.priceAdapter = priceAdapter;
        self.minInitialMarginRateX18 = minInitialMarginRateX18;
        self.maintenanceMarginRateX18 = maintenanceMarginRateX18;
        self.maxOpenInterest = maxOpenInterest;
        self.maxFundingVelocity = maxFundingVelocity;
        self.skewScale = skewScale;
        self.orderFees = orderFees;
    }
}
