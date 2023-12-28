// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { OrderFees } from "./OrderFees.sol";

library MarketConfiguration {
    struct Data {
        string name;
        string symbol;
        uint128 minInitialMarginRate;
        uint128 maintenanceMarginRate;
        uint128 maxOpenInterest;
        uint256 skewScale;
        uint128 maxFundingVelocity;
        OrderFees.Data orderFees;
    }
}
