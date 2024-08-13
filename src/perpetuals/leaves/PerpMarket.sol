// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.25;

// Zaros dependencies
import { IAggregatorV3 } from "@zaros/external/chainlink/interfaces/IAggregatorV3.sol";
import { Constants } from "@zaros/utils/Constants.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { Math } from "@zaros/utils/Math.sol";
import { ChainlinkUtil } from "@zaros/external/chainlink/ChainlinkUtil.sol";
import { OrderFees } from "./OrderFees.sol";
import { MarketConfiguration } from "./MarketConfiguration.sol";
import { SettlementConfiguration } from "./SettlementConfiguration.sol";

// Open Zeppelin dependencies
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
    using MarketConfiguration for MarketConfiguration.Data;

    /// @dev Constant base domain used to access a given PerpMarket's storage slot.
    string internal constant PERPS_MARKET_DOMAIN = "fi.zaros.markets.PerpMarket";

    /// @param priceAdapter The price adapter contract, which stores onchain and outputs the market's index price.
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

    function getIndexPrice(Data storage self) internal view returns (UD60x18 indexPrice) {
        address priceAdapter = self.configuration.priceAdapter;
        if (priceAdapter == address(0)) {
            revert Errors.PriceAdapterNotDefined(self.id);
        }

        indexPrice = ChainlinkUtil.getPrice(IAggregatorV3(priceAdapter));
    }

    /// @notice Returns the given market's mark price.
    /// @dev The mark price is calculated given the bid/ask or median price of the underlying offchain provider (e.g
    /// CL Data Streams),
    /// and the skew of the market which is used to compute the price impact impact oh the trade.
    /// @dev Liquidity providers of the ZLP Vaults are automatically market making for prices ranging the bid/ask
    /// spread provided by
    /// the offchain oracle with the added spread based on the skew and the configured skew scale.
    function getMarkPrice(
        Data storage self,
        SD59x18 skewDelta,
        UD60x18 indexPriceX18
    )
        internal
        view
        returns (UD60x18)
    {
        SD59x18 skewScale = sd59x18(uint256(self.configuration.skewScale).toInt256());
        SD59x18 skew = sd59x18(self.skew);

        SD59x18 priceImpactBeforeDelta = skew.div(skewScale);
        SD59x18 newSkew = skew.add(skewDelta);
        SD59x18 priceImpactAfterDelta = newSkew.div(skewScale);

        UD60x18 priceBeforeDelta =
            indexPriceX18.intoSD59x18().add(indexPriceX18.intoSD59x18().mul(priceImpactBeforeDelta)).intoUD60x18();
        UD60x18 priceAfterDelta =
            indexPriceX18.intoSD59x18().add(indexPriceX18.intoSD59x18().mul(priceImpactAfterDelta)).intoUD60x18();

        UD60x18 markPrice = priceBeforeDelta.add(priceAfterDelta).div(ud60x18Convert(2));

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

    /// @dev When the skew is zero, taker fee will be charged.
    function getOrderFeeUsd(
        Data storage self,
        SD59x18 sizeDelta,
        UD60x18 markPriceX18
    )
        internal
        view
        returns (SD59x18)
    {
        SD59x18 skew = sd59x18(self.skew);
        SD59x18 feeBps;

        bool isSkewGtZero = skew.gt(SD_ZERO);
        bool isBuyOrder = sizeDelta.gt(SD_ZERO);

        if (isSkewGtZero != isBuyOrder) {
            feeBps = sd59x18((self.configuration.orderFees.makerFee));
        } else {
            feeBps = sd59x18((self.configuration.orderFees.takerFee));
        }

        return markPriceX18.intoSD59x18().mul(sizeDelta).abs().mul(feeBps);
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
        return sd59x18(self.lastFundingFeePerUnit).add(getPendingFundingFeePerUnit(self, fundingRate, price));
    }

    function getPendingFundingFeePerUnit(
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
        return ud60x18Convert(block.timestamp - self.lastFundingTime).div(
            ud60x18Convert(Constants.PROPORTIONAL_FUNDING_PERIOD)
        );
    }

    /// @notice Verifies the market's open interest and skew limits based on the next state.
    /// @dev During liquidation we skip the max skew check, so the engine can always liquidate unhealthy accounts.
    /// @dev If the case outlined above happens and the maxSkew is crossed, the market will only allow orders that
    /// reduce the skew.
    /// @param self The PerpMarket storage pointer.
    /// @param sizeDelta The size delta of the order.
    /// @param oldPositionSize The old position size.
    /// @param newPositionSize The new position size.
    /// @param shouldCheckNewOpenInterestAndNewSkew Whether to check the new open interest and skew.
    function checkOpenInterestLimits(
        Data storage self,
        SD59x18 sizeDelta,
        SD59x18 oldPositionSize,
        SD59x18 newPositionSize,
        bool shouldCheckNewOpenInterestAndNewSkew
    )
        internal
        view
        returns (UD60x18 newOpenInterest, SD59x18 newSkew)
    {
        // load max & current open interest for this perp market uint128 -> UD60x18
        UD60x18 maxOpenInterest = ud60x18(self.configuration.maxOpenInterest);
        UD60x18 currentOpenInterest = ud60x18(self.openInterest);

        // calculate new open interest which would result from proposed trade
        // by subtracting old position size then adding new position size to
        // current open interest
        newOpenInterest =
            currentOpenInterest.sub(oldPositionSize.abs().intoUD60x18()).add(newPositionSize.abs().intoUD60x18());

        // if new open interest would be greater than this market's max open interest,
        // we still want to allow trades as long as they decrease the open interest. This
        // allows traders to reduce/close their positions in markets where protocol admins
        // have reduced the max open interest to reduce the protocol's exposure to a given
        // perp market
        if (newOpenInterest.gt(maxOpenInterest) && shouldCheckNewOpenInterestAndNewSkew) {
            // is the proposed trade reducing open interest?
            bool isReducingOpenInterest = currentOpenInterest.gt(newOpenInterest);

            // revert if the proposed trade isn't reducing open interest
            if (!isReducingOpenInterest) {
                revert Errors.ExceedsOpenInterestLimit(
                    self.id, maxOpenInterest.intoUint256(), newOpenInterest.intoUint256()
                );
            }
        }

        // load max & current skew for this perp market uint128 -> UD60x18 -> SD59x18
        SD59x18 maxSkew = ud60x18(self.configuration.maxSkew).intoSD59x18();
        // int128 -> SD59x18
        SD59x18 currentSkew = sd59x18(self.skew);

        // calculate new skew
        newSkew = currentSkew.add(sizeDelta);

        // similar logic to the open interest check; if the new skew is greater than
        // the max, we still want to allow trades as long as they decrease the skew
        if (newSkew.abs().gt(maxSkew) && shouldCheckNewOpenInterestAndNewSkew) {
            bool isReducingSkew = currentSkew.abs().gt(newSkew.abs());

            if (!isReducingSkew) {
                revert Errors.ExceedsSkewLimit(self.id, maxSkew.intoUint256(), newSkew.intoInt256());
            }
        }
    }

    function checkTradeSize(Data storage self, SD59x18 sizeDeltaX18) internal view {
        if (sizeDeltaX18.abs().intoUD60x18().lt(ud60x18(self.configuration.minTradeSizeX18))) {
            revert Errors.TradeSizeTooSmall();
        }
    }

    function updateFunding(Data storage self, SD59x18 fundingRate, SD59x18 fundingFeePerUnit) internal {
        self.lastFundingRate = fundingRate.intoInt256();
        self.lastFundingFeePerUnit = fundingFeePerUnit.intoInt256();
        self.lastFundingTime = block.timestamp;
    }

    function updateOpenInterest(Data storage self, UD60x18 newOpenInterest, SD59x18 newSkew) internal {
        self.skew = newSkew.intoInt256().toInt128();
        self.openInterest = newOpenInterest.intoUint128();
    }

    struct CreateParams {
        uint128 marketId;
        string name;
        string symbol;
        address priceAdapter;
        uint128 initialMarginRateX18;
        uint128 maintenanceMarginRateX18;
        uint128 maxOpenInterest;
        uint128 maxSkew;
        uint128 maxFundingVelocity;
        uint128 minTradeSizeX18;
        uint256 skewScale;
        SettlementConfiguration.Data marketOrderConfiguration;
        SettlementConfiguration.Data[] customOrdersConfiguration;
        OrderFees.Data orderFees;
    }

    function create(CreateParams memory params) internal {
        Data storage self = load(params.marketId);
        if (self.id != 0) {
            revert Errors.MarketAlreadyExists(params.marketId);
        }

        self.id = params.marketId;
        self.initialized = true;

        self.configuration.update(
            params.name,
            params.symbol,
            params.priceAdapter,
            params.initialMarginRateX18,
            params.maintenanceMarginRateX18,
            params.maxOpenInterest,
            params.maxSkew,
            params.maxFundingVelocity,
            params.minTradeSizeX18,
            params.skewScale,
            params.orderFees
        );
        SettlementConfiguration.update(
            params.marketId, SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID, params.marketOrderConfiguration
        );

        if (params.customOrdersConfiguration.length > 0) {
            for (uint256 i = 0; i < params.customOrdersConfiguration.length; i++) {
                uint128 nextStrategyId = ++self.nextStrategyId;
                SettlementConfiguration.update(params.marketId, nextStrategyId, params.customOrdersConfiguration[i]);
            }
        }
    }
}
