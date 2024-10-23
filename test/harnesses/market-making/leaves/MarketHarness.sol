// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Market } from "@zaros/market-making/leaves/Market.sol";

// Open Zeppelin dependencies
import { EnumerableMap } from "@openzeppelin/utils/structs/EnumerableMap.sol";
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";

contract MarketHarness {
    using EnumerableMap for EnumerableMap.AddressToUintMap;
    using EnumerableSet for EnumerableSet.UintSet;

    function workaround_getMarketId(uint128 marketId) external view returns (uint128) {
        Market.Data storage market = Market.load(marketId);
        return market.id;
    }

    function workaround_setMarketId(uint128 marketId) external returns (uint128) {
        Market.Data storage market = Market.load(marketId);
        market.id = marketId;
        return market.id;
    }

    function workaround_getReceivedMarketFees(uint128 marketId, address asset) external view returns (uint256) {
        Market.Data storage market = Market.load(marketId);
        return market.receivedMarketFees.get(asset);
    }

    function workaround_setReceivedMarketFees(uint128 marketId, address asset, uint256 amount) external {
        Market.Data storage market = Market.load(marketId);
        market.receivedMarketFees.set(asset, amount);
    }

    function workaround_getPendingProtocolWethReward(uint128 marketId) external view returns (uint256) {
        Market.Data storage market = Market.load(marketId);
        return market.pendingProtocolWethReward;
    }
}
