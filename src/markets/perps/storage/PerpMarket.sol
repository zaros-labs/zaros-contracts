// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { IAggregatorV3 } from "@zaros/external/chainlink/interfaces/IAggregatorV3.sol";
import { Constants } from "@zaros/utils/Constants.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { Math } from "@zaros/utils/Math.sol";
import { OracleUtil } from "@zaros/utils/OracleUtil.sol";
import { OrderFees } from "./OrderFees.sol";
import { Position } from "./Position.sol";
import { MarketConfiguration } from "./MarketConfiguration.sol";
import { SettlementConfiguration } from "./SettlementConfiguration.sol";

// Open Zeppelin dependencies
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

// PRB Math dependencies
import { UD60x18, ud60x18, convert } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18, unary, UNIT as SD_UNIT, ZERO as SD_ZERO } from "@prb-math/SD59x18.sol";

/// @title The PerpMarket namespace.
library PerpMarket {
    using SafeCast for uint256;

    /// @dev Constant base domain used to access a given PerpMarket's storage slot.
    string internal constant PERPS_MARKET_DOMAIN = "fi.zaros.markets.PerpMarket";

    struct Data {
        uint128 id;
        int128 skew;
        uint128 size;
        uint128 nextStrategyId;
        bool initialized;
        int256 lastFundingRate;
        int256 lastFundingFee;
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
        uint128 minInitialMarginRate,
        uint128 maintenanceMarginRate,
        uint128 maxOpenInterest,
        uint256 skewScale,
        uint128 maxFundingVelocity,
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
            orderFees: orderFees,
            skewScale: skewScale,
            maxFundingVelocity: maxFundingVelocity
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
        return sd59x18(self.lastFundingRate).add(
            getCurrentFundingVelocity(self).mul(proportionalElapsedSinceLastFunding(self).intoSD59x18())
        );
    }

    function getCurrentFundingVelocity(Data storage self) internal view returns (SD59x18) {
        SD59x18 maxFundingVelocity = sd59x18(uint256(self.configuration.maxFundingVelocity).toInt256());
        SD59x18 skewScale = sd59x18(uint256(self.configuration.skewScale).toInt256());

        SD59x18 skew = sd59x18(self.skew);

        if (skewScale.isZero()) {
            return SD_ZERO;
        }

        SD59x18 proportionalSkew = skew.div(skewScale);
        SD59x18 proportionalSkewBounded = Math.min(Math.max(unary(SD_UNIT), proportionalSkew), SD_UNIT);
        return proportionalSkewBounded.mul(maxFundingVelocity);
    }

    function calculateNextFundingFeePerUnit(
        Data storage self,
        SD59x18 fundingRate,
        UD60x18 timeElapsed,
        UD60x18 price
    )
        internal
        view
        returns (SD59x18)
    {
        return sd59x18(self.lastFundingFee).add(pendingFundingFee(self, fundingRate, timeElapsed, price));
    }

    function pendingFundingFee(
        Data storage self,
        SD59x18 fundingRate,
        UD60x18 timeElapsed,
        UD60x18 price
    )
        internal
        view
        returns (SD59x18)
    {
        SD59x18 avgFundingRate = unary(sd59x18(self.lastFundingRate).add(fundingRate)).div((SD_UNIT.mul(sd59x18(2))));

        return avgFundingRate.mul(timeElapsed.intoSD59x18()).mul(price.intoSD59x18());
    }

    function proportionalElapsedSinceLastFunding(Data storage self) internal view returns (UD60x18) {
        return convert(block.timestamp - self.lastFundingTime).div(convert(Constants.FUNDING_PERIOD));
    }
}
