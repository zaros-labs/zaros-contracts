// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { MarketDebt } from "@zaros/market-making/leaves/MarketDebt.sol";

// Open Zeppelin dependencies
import { EnumerableMap } from "@openzeppelin/utils/structs/EnumerableMap.sol";

contract MarketDebtHarness {
    using EnumerableMap for EnumerableMap.AddressToUintMap;
    
    function workaround_getMarketId(uint128 marketId) external view returns (uint128) {
        MarketDebt.Data storage marketDebtData = MarketDebt.load(marketId);
        return marketDebtData.marketId;
    }

    function workaround_setMarketId(uint128 marketId, uint128 newId) external returns (uint128) {
        MarketDebt.Data storage marketDebtData = MarketDebt.load(marketId);
        marketDebtData.marketId = newId;
        return marketDebtData.marketId;
    }

    function workaround_getMarketFees(uint128 marketId) external view returns (uint256){
        MarketDebt.Data storage marketDebtData = MarketDebt.load(marketId);
        return marketDebtData.collectedFees.collectedMarketFees;
    }

    function workaround_getFeeRecipientsFees(uint128 marketId) external view returns (uint256){
        MarketDebt.Data storage marketDebtData = MarketDebt.load(marketId);
        return marketDebtData.collectedFees.collectedFeeRecipientsFees;
    }

    function workaround_getReceivedOrderFees(uint128 marketId, address asset) external view returns (uint256) {
        MarketDebt.Data storage marketDebtData = MarketDebt.load(marketId);
        return marketDebtData.collectedFees.receivedOrderFees.get(asset);
    }

    function workaround_setFeeRecipientsFees(uint128 marketId, uint256 collectedFees) external {
        MarketDebt.Data storage marketDebtData = MarketDebt.load(marketId);
        marketDebtData.collectedFees.collectedFeeRecipientsFees = collectedFees;
    }
}