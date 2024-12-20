// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Market, UD60x18 } from "@zaros/market-making/leaves/Market.sol";

// Open Zeppelin dependencies
import { EnumerableMap } from "@openzeppelin/utils/structs/EnumerableMap.sol";
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";

contract MarketHarness {
    using EnumerableMap for EnumerableMap.AddressToUintMap;
    using EnumerableSet for EnumerableSet.UintSet;
    using Market for Market.Data;

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
        return market.receivedFees.get(asset);
    }

    function workaround_setReceivedMarketFees(uint128 marketId, address asset, uint256 amount) external {
        Market.Data storage market = Market.load(marketId);
        market.receivedFees.set(asset, amount);
    }

    function workaround_getPendingProtocolWethReward(uint128 marketId) external view returns (uint256) {
        Market.Data storage market = Market.load(marketId);
        return market.availableProtocolWethReward;
    }

    function workaround_getIfReceivedMarketFeesContainsTheAsset(
        uint128 marketId,
        address asset
    )
        external
        view
        returns (bool)
    {
        Market.Data storage market = Market.load(marketId);
        return market.receivedFees.contains(asset);
    }

    function workaround_getMarketEngine(uint128 marketId) external view returns (address) {
        Market.Data storage market = Market.load(marketId);
        return market.engine;
    }

    function workaround_getAutoDeleverageStartThreshold(uint128 marketId) external view returns (uint128) {
        Market.Data storage market = Market.load(marketId);
        return market.autoDeleverageStartThreshold;
    }

    function workaround_getAutoDeleverageEndThreshold(uint128 marketId) external view returns (uint128) {
        Market.Data storage market = Market.load(marketId);
        return market.autoDeleverageEndThreshold;
    }

    function workaround_getAutoDeleveragePowerScale(uint128 marketId) external view returns (uint128) {
        Market.Data storage market = Market.load(marketId);
        return market.autoDeleverageExponentZ;
    }

    function workaround_updateMarketTotalDelegatedCreditUsd(
        uint128 marketId,
        uint128 totalDelegatedCreditUsd
    )
        external
    {
        Market.Data storage market = Market.load(marketId);
        market.totalDelegatedCreditUsd = totalDelegatedCreditUsd;
    }

    function workaround_getMarketCreditDeposit(uint128 marketId, address asset) external view returns (uint256) {
        Market.Data storage market = Market.load(marketId);
        return market.creditDeposits.get(asset);
    }

    function workaround_getCreditDepositsValueUsd(uint128 marketId)
        external
        view
        returns (uint256 creditDepositsValueUsd)
    {
        Market.Data storage market = Market.load(marketId);
        creditDepositsValueUsd = market.getCreditDepositsValueUsd().intoUint256();
    }
}
