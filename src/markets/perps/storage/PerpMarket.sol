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
import { UD60x18, ud60x18, convert as ud60x18Convert } from "@prb-math/UD60x18.sol";
import {
    SD59x18,
    sd59x18,
    unary,
    UNIT as SD_UNIT,
    ZERO as SD_ZERO,
    convert as sd59x18Convert
} from "@prb-math/SD59x18.sol";

/// @title The PerpMarket namespace.
library PerpMarket {
    using SafeCast for uint256;
    using SafeCast for int256;

    /// @dev Constant base domain used to access a given PerpMarket's storage slot.
    string internal constant PERPS_MARKET_DOMAIN = "fi.zaros.markets.PerpMarket";

    struct Data {
        uint128 id;
        int128 skew;
        uint128 openInterest;
        uint128 nextStrategyId;
        bool initialized;
        int256 lastFundingRate;
        int256 lastFundingFeePerUnit;
        uint256 lastFundingTime;
        MarketConfiguration.Data configuration;
    }

    function load(uint128 marketId) internal pure returns (Data storage perpMarket) {
        bytes32 slot = keccak256(abi.encode(PERPS_MARKET_DOMAIN, marketId));
        assembly {
            perpMarket.slot := slot
        }
    }

    function loadActive(uint128 marketId) internal pure returns (Data storage perpMarket) {
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

    function validateNewState(Data storage self, SD59x18 sizeDelta) internal view {
        UD60x18 maxOpenInterest = ud60x18(self.configuration.maxOpenInterest);
        UD60x18 newOpenInterest = ud60x18(self.openInterest).add((sizeDelta).abs().intoUD60x18());

        if (newOpenInterest.gt(maxOpenInterest)) {
            revert Errors.ExceedsOpenInterestLimit(
                self.id, maxOpenInterest.intoUint256(), newOpenInterest.intoUint256()
            );
        }
    }

    function getMarkPrice(Data storage self, SD59x18 skewDelta, UD60x18 indexPrice) internal view returns (UD60x18) {
        SD59x18 skewScale = sd59x18(uint256(self.configuration.skewScale).toInt256());
        SD59x18 skew = sd59x18(self.skew);

        SD59x18 priceImpactBeforeDelta = skew.div(skewScale);
        SD59x18 newSkew = skew.add(skewDelta);
        SD59x18 priceImpactAfterDelta = newSkew.div(skewScale);

        SD59x18 priceBeforeDelta = indexPrice.intoSD59x18().mul(SD_UNIT.add(priceImpactBeforeDelta));
        SD59x18 priceAfterDelta = indexPrice.intoSD59x18().mul(SD_UNIT.add(priceImpactAfterDelta));

        UD60x18 markPrice = priceBeforeDelta.add(priceAfterDelta).div(sd59x18Convert(2)).intoUD60x18();

        return markPrice;
    }

    function getCurrentFundingRate(Data storage self) internal view returns (SD59x18) {
        return sd59x18(self.lastFundingRate).add(
            getCurrentFundingVelocity(self).mul(getProportionalElapsedSinceLastFunding(self).intoSD59x18())
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

    function getOrderFeeUsd(Data storage self, SD59x18 sizeDelta, UD60x18 price) internal view returns (SD59x18) {
        SD59x18 skew = sd59x18(self.skew);
        SD59x18 feeBps;

        bool isPositiveSkew = skew.gt(SD_ZERO);
        bool isBuyOrder = sizeDelta.gt(SD_ZERO);

        if (isPositiveSkew == isBuyOrder) {
            feeBps = sd59x18((self.configuration.orderFees.takerFee));
        } else {
            feeBps = sd59x18((self.configuration.orderFees.makerFee));
        }

        return price.intoSD59x18().mul(sizeDelta).abs().mul(feeBps);
    }

    function getNextFundingFeePerUnit(
        Data storage self,
        SD59x18 fundingRate,
        UD60x18 price
    )
        internal
        view
        returns (SD59x18)
    {
        return sd59x18(self.lastFundingFeePerUnit).add(getPendingFundingFee(self, fundingRate, price));
    }

    function getPendingFundingFee(
        Data storage self,
        SD59x18 fundingRate,
        UD60x18 price
    )
        internal
        view
        returns (SD59x18)
    {
        SD59x18 avgFundingRate = unary(sd59x18(self.lastFundingRate).add(fundingRate)).div(sd59x18Convert(2));

        return avgFundingRate.mul(getProportionalElapsedSinceLastFunding(self).intoSD59x18()).mul(price.intoSD59x18());
    }

    function getProportionalElapsedSinceLastFunding(Data storage self) internal view returns (UD60x18) {
        return ud60x18Convert(block.timestamp - self.lastFundingTime).div(ud60x18Convert(Constants.FUNDING_INTERVAL));
    }

    function updateState(
        Data storage self,
        SD59x18 sizeDelta,
        SD59x18 fundingRate,
        SD59x18 fundingFeePerUnit
    )
        internal
    {
        self.skew = sd59x18(self.skew).add(sizeDelta).intoInt256().toInt128();
        self.openInterest = ud60x18(self.openInterest).add((sizeDelta).abs().intoUD60x18()).intoUint128();
        self.lastFundingRate = fundingRate.intoInt256();
        self.lastFundingFeePerUnit = fundingFeePerUnit.intoInt256();
        self.lastFundingTime = block.timestamp;
    }
}
