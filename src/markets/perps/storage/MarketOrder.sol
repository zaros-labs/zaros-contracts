// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { PerpsConfiguration } from "./PerpsConfiguration.sol";

library MarketOrder {
    using PerpsConfiguration for PerpsConfiguration.Data;

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

    function clear(Data storage self) internal { }

    function checkPendingOrder(Data storage self) internal view {
        PerpsConfiguration.Data storage perpsConfiguration = PerpsConfiguration.load();
        (uint128 marketOrderMinLifetime, uint128 maxPositionsPerAccount) =
            (perpsConfiguration.marketOrderMinLifetime, perpsConfiguration.maxPositionsPerAccount);

        if (self.timestamp != 0 && block.timestamp - self.timestamp <= marketOrderMinLifetime) {
            revert Errors.MarketOrderAlreadyPending(self.timestamp);
        }
    }
}
