// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { IAggregatorV3 } from "@zaros/external/chainlink/interfaces/IAggregatorV3.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { OracleUtil } from "@zaros/utils/OracleUtil.sol";
import { OrderFees } from "./OrderFees.sol";
import { Position } from "./Position.sol";
import { MarketConfiguration } from "./MarketConfiguration.sol";
import { SettlementConfiguration } from "./SettlementConfiguration.sol";

// Open Zeppelin dependencies
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18 } from "@prb-math/SD59x18.sol";

/// @title The PerpMarket namespace.
library PerpMarket {
    /// @dev Constant base domain used to access a given PerpMarket's storage slot.
    string internal constant PERPS_MARKET_DOMAIN = "fi.zaros.markets.PerpMarket";

    struct Data {
        uint128 id;
        int128 skew;
        uint128 size;
        uint128 nextStrategyId;
        bool initialized;
        int256 lastFundingRate;
        int256 lastFundingValue;
        uint256 lastFundingTime;
        MarketConfiguration.Data configuration;
    }

    function load(uint128 marketId) internal pure returns (Data storage perpMarket) {
        bytes32 slot = keccak256(abi.encode(PERPS_MARKET_DOMAIN, marketId));
        assembly {
            perpMarket.slot := slot
        }
    }

    function loadActive(uint128 marketId) internal view returns (Data storage perpMarket) {
        perpMarket = load(marketId);
    }

    function create(
        uint128 marketId,
        string memory name,
        string memory symbol,
        uint128 maintenanceMarginRate,
        uint128 maxOpenInterest,
        uint128 minInitialMarginRate,
        SettlementConfiguration.Data memory marketOrderStrategy,
        SettlementConfiguration.Data[] memory customTriggerStrategies,
        OrderFees.Data memory orderFees
    )
        internal
    {
        Data storage self = load(marketId);
        if (self.id != 0) {
            revert Errors.MarketAlreadyExists(marketId);
        }

        // TODO: remember to test gas cost / number of sstores here
        self.id = marketId;
        self.initialized = true;
        self.configuration = MarketConfiguration.Data({
            name: name,
            symbol: symbol,
            minInitialMarginRate: minInitialMarginRate,
            maintenanceMarginRate: maintenanceMarginRate,
            maxOpenInterest: maxOpenInterest,
            orderFees: orderFees
        });

        SettlementConfiguration.create(marketId, 0, marketOrderStrategy);

        if (customTriggerStrategies.length > 0) {
            for (uint256 i = 0; i < customTriggerStrategies.length; i++) {
                uint128 nextStrategyId = ++self.nextStrategyId;
                SettlementConfiguration.create(marketId, nextStrategyId, customTriggerStrategies[i]);
            }
        }
    }

    /// @notice TODO: Use Settlement Strategy
    function getIndexPrice(Data storage self) internal view returns (UD60x18 price) {
        return ud60x18(0);
    }

    function getMarkPrice(Data storage self, bytes memory data) internal view returns (UD60x18) {
        // TODO: load settlement strategy and return the mark price based on the report data and report type
        return ud60x18(0);
    }

    function getCurrentFundingRate(Data storage self) internal view returns (SD59x18) {
        // SD59x18 currentFundingVelocity = getCurrentFundingVelocity(self);
    }

    function getCurrentFundingVelocity(Data storage self) internal view returns (SD59x18) {
        return sd59x18(0);
    }

    function calculateNextFundingFeePerUnit(Data storage self, UD60x18 price) internal view returns (SD59x18) {
        return sd59x18(0);
    }
}
