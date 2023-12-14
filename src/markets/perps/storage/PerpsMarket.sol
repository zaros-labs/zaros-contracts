// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { IAggregatorV3 } from "@zaros/external/chainlink/interfaces/IAggregatorV3.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { OracleUtil } from "@zaros/utils/OracleUtil.sol";
import { OrderFees } from "./OrderFees.sol";
import { Position } from "./Position.sol";
import { SettlementConfiguration } from "./SettlementConfiguration.sol";

// Open Zeppelin dependencies
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18 } from "@prb-math/SD59x18.sol";

/// @title The PerpsMarket namespace.
library PerpsMarket {
    /// @dev Constant base domain used to access a given PerpsMarket's storage slot.
    string internal constant PERPS_MARKET_DOMAIN = "fi.zaros.markets.PerpsMarket";

    struct Data {
        string name;
        string symbol;
        uint128 id;
        uint128 minInitialMarginRate;
        uint128 maintenanceMarginRate;
        uint128 maxOpenInterest;
        int128 skew;
        uint128 size;
        uint128 nextStrategyId;
        OrderFees.Data orderFees;
    }

    function load(uint128 marketId) internal pure returns (Data storage perpsMarket) {
        bytes32 slot = keccak256(abi.encode(PERPS_MARKET_DOMAIN, marketId));
        assembly {
            perpsMarket.slot := slot
        }
    }

    function loadActive(uint128 marketId) internal view returns (Data storage perpsMarket) {
        perpsMarket = load(marketId);
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
        self.name = name;
        self.symbol = symbol;
        self.maintenanceMarginRate = maintenanceMarginRate;
        self.maxOpenInterest = maxOpenInterest;
        self.minInitialMarginRate = minInitialMarginRate;
        self.orderFees = orderFees;

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
        return sd59x18(0);
    }

    function getCurrentFundingVelocity(Data storage self) internal view returns (SD59x18) {
        return sd59x18(0);
    }

    function calculateNextFundingFeePerUnit(Data storage self, UD60x18 price) internal view returns (SD59x18) {
        return sd59x18(0);
    }
}
