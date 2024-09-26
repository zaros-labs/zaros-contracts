// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { MarketDebt } from "@zaros/market-making/leaves/MarketDebt.sol";

// Open Zeppelin dependencies
import { EnumerableMap } from "@openzeppelin/utils/structs/EnumerableMap.sol";
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";

import { console } from "forge-std/console.sol";


contract MarketDebtHarness {
    using EnumerableMap for EnumerableMap.AddressToUintMap;
    using EnumerableSet for EnumerableSet.UintSet;

    function workaround_getMarketId(uint128 marketId) external view returns (uint128) {
        MarketDebt.Data storage marketDebt = MarketDebt.load(marketId);
        return marketDebt.marketId;
    }

    function workaround_setMarketId(uint128 marketId) external returns (uint128) {
        MarketDebt.Data storage marketDebt = MarketDebt.load(marketId);
        marketDebt.marketId = marketId;
        return marketDebt.marketId;
    }

    function workaround_getFeeRecipientsFees(uint128 marketId) external view returns (uint128){
        MarketDebt.Data storage marketDebt = MarketDebt.load(marketId);
        return marketDebt.collectedFees.collectedFeeRecipientsFees;
    }

    function workaround_getReceivedOrderFees(uint128 marketId, address asset) external view returns (uint256) {
        MarketDebt.Data storage marketDebt = MarketDebt.load(marketId);
        return marketDebt.collectedFees.receivedOrderFees.get(asset);
    }

    function workaround_setFeeRecipientsFees(uint128 marketId, uint128 collectedFees) external {
        MarketDebt.Data storage marketDebt = MarketDebt.load(marketId);
        marketDebt.collectedFees.collectedFeeRecipientsFees = collectedFees;
    }

    function workaround_setConnectedVaults(uint128 marketId, uint256 index, uint256[] memory connectedVaults) external {
        MarketDebt.Data storage marketDebt = MarketDebt.load(marketId);
        
        for (uint i = 0; i < connectedVaults.length; ++i) {
            marketDebt.connectedVaultsIds.push();
            EnumerableSet.UintSet storage vaults = marketDebt.connectedVaultsIds[i];
            
            vaults.add(connectedVaults[i]);
        }
    }
}