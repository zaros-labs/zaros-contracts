// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { GlobalConfiguration } from "./GlobalConfiguration.sol";

library MarketOrder {
    using GlobalConfiguration for GlobalConfiguration.Data;

    /// @notice Constant base domain used to access a given MarketOrder's storage slot.
    string internal constant MARKET_ORDER_DOMAIN = "fi.zaros.markets.perps.storage.MarketOrder";

    struct Data {
        int128 sizeDelta;
        uint128 acceptablePrice;
        uint256 timestamp;
    }

    function load(uint128 accountId, uint128 marketId) internal pure returns (Data storage self) {
        bytes32 slot = keccak256(abi.encode(MARKET_ORDER_DOMAIN, accountId, marketId));

        assembly {
            self.slot := slot
        }
    }

    function update(Data storage self, int128 sizeDelta, uint128 acceptablePrice) internal {
        self.sizeDelta = sizeDelta;
        self.acceptablePrice = acceptablePrice;
        self.timestamp = block.timestamp;
    }

    // TODO: Implement
    function clear(Data storage self) internal { }

    function checkPendingOrder(Data storage self) internal view {
        GlobalConfiguration.Data storage globalConfiguration = GlobalConfiguration.load();
        uint128 marketOrderMaxLifetime = globalConfiguration.marketOrderMaxLifetime;

        if (self.timestamp != 0 && block.timestamp - self.timestamp <= marketOrderMaxLifetime) {
            revert Errors.MarketOrderStillPending(self.timestamp);
        }
    }
}
