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

    /// @notice ERC7201 storage location.
    bytes32 internal constant PERP_MARKET_LOCATION =
        keccak256(abi.encode(uint256(keccak256("fi.zaros.perpetuals.PerpMarket")) - 1)) & ~bytes32(uint256(0xff));

    /// @notice {PerpMarket} namespace storage structure.
    /// @param id The perp market id.
    /// @param skew The perp market's current skew.
    /// @param openInterest The perp market's current open interest.
    /// @param nextStrategyId The perp market's next settlement strategy id.
    /// @param initialized Whether the perp market is initialized or not.
    /// @param lastFundingRate The perp market's last funding rate value.
    /// @param lastFundingFeePerUnit The perp market's last funding fee per unit value.
    /// @param lastFundingTime The perp market's last funding timestamp.
    /// @param configuration The perp market's configuration data.
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

    /// @notice Loads a {PerpMarket}.
    /// @param marketId The perp market id.
    function load(uint128 marketId) internal pure returns (Data storage perpMarket) {
        bytes32 slot = keccak256(abi.encode(PERP_MARKET_LOCATION, marketId));
        assembly {
            perpMarket.slot := slot
        }
    }

    /// @notice Returns the PerpMarket index price based on the price adapter.
    /// @param self The PerpMarket storage pointer.
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
    /// @param self The PerpMarket storage pointer.
    /// @param skewDelta The skew delta to apply to the mark price calculation.
    /// @param indexPriceX18 The index price of the market.
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

        SD59x18 cachedIndexPriceX18 = indexPriceX18.intoSD59x18();

        UD60x18 priceBeforeDelta =
            cachedIndexPriceX18.add(cachedIndexPriceX18.mul(priceImpactBeforeDelta)).intoUD60x18();
        UD60x18 priceAfterDelta =
            cachedIndexPriceX18.add(cachedIndexPriceX18.mul(priceImpactAfterDelta)).intoUD60x18();

        UD60x18 markPrice = priceBeforeDelta.add(priceAfterDelta).div(ud60x18Convert(2));

        return markPrice;
    }

    /// @notice Returns the current funding rate of the given market.
    /// @param self The PerpMarket storage pointer.
    function getCurrentFundingRate(Data storage self) internal view returns (SD59x18) {
        return sd59x18(self.lastFundingRate).add(
            getCurrentFundingVelocity(self).mul(getProportionalElapsedSinceLastFunding(self).intoSD59x18())
        );
    }

    /// @notice Returns the current funding velocity of the given market.
    /// @param self The PerpMarket storage pointer.
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

    /// @notice Returns the maker or taker order fee in USD.
    /// @dev When the skew is zero, taker fee will be charged.
    /// @param self The PerpMarket storage pointer.
    /// @param sizeDelta The size delta of the order.
    /// @param markPriceX18 The mark price of the market.
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

    /// @notice Returns the next funding fee per unit value.
    /// @param self The PerpMarket storage pointer.
    /// @param fundingRate The market's current funding rate.
    /// @param markPriceX18 The market's current mark price.
    function getNextFundingFeePerUnit(
        Data storage self,
        SD59x18 fundingRate,
        UD60x18 markPriceX18
    )
        internal
        view
        returns (SD59x18)
    {
        return sd59x18(self.lastFundingFeePerUnit).add(getPendingFundingFeePerUnit(self, fundingRate, markPriceX18));
    }

    /// @notice Returns the pending funding fee per unit value to accumulate.
    /// @param self The PerpMarket storage pointer.
    /// @param fundingRate The market's current funding rate.
    /// @param markPriceX18 The market's current mark price.
    function getPendingFundingFeePerUnit(
        Data storage self,
        SD59x18 fundingRate,
        UD60x18 markPriceX18
    )
        internal
        view
        returns (SD59x18)
    {
        SD59x18 avgFundingRate = unary(sd59x18(self.lastFundingRate).add(fundingRate)).div(sd59x18Convert(2));

        return avgFundingRate.mul(getProportionalElapsedSinceLastFunding(self).intoSD59x18()).mul(
            markPriceX18.intoSD59x18()
        );
    }

    /// @notice Returns the proportional elapsed time since the last funding.
    /// @param self The PerpMarket storage pointer.
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
    /// @param shouldCheckMaxSkew Whether to check the max skew limit.
    function checkOpenInterestLimits(
        Data storage self,
        SD59x18 sizeDelta,
        SD59x18 oldPositionSize,
        SD59x18 newPositionSize,
        bool shouldCheckMaxSkew
    )
        internal
        view
        returns (UD60x18 newOpenInterest, SD59x18 newSkew)
    {
        UD60x18 maxOpenInterest = ud60x18(self.configuration.maxOpenInterest);
        newOpenInterest = ud60x18(self.openInterest).sub(oldPositionSize.abs().intoUD60x18()).add(
            newPositionSize.abs().intoUD60x18()
        );
        newSkew = sd59x18(self.skew).add(sizeDelta);

        if (newOpenInterest.gt(maxOpenInterest)) {
            revert Errors.ExceedsOpenInterestLimit(
                self.id, maxOpenInterest.intoUint256(), newOpenInterest.intoUint256()
            );
        }

        bool isReducingSkew = sd59x18(self.skew).abs().gt(newSkew.abs());

        if (
            shouldCheckMaxSkew && newSkew.abs().gt(ud60x18(self.configuration.maxSkew).intoSD59x18())
                && !isReducingSkew
        ) {
            revert Errors.ExceedsSkewLimit(self.id, self.configuration.maxSkew, newSkew.intoInt256());
        }
    }

    /// @notice Verifies if the trade size is greater than the minimum trade size.
    /// @param self The PerpMarket storage pointer.
    /// @param sizeDeltaX18 The size delta of the order.
    function checkTradeSize(Data storage self, SD59x18 sizeDeltaX18) internal view {
        if (sizeDeltaX18.abs().intoUD60x18().lt(ud60x18(self.configuration.minTradeSizeX18))) {
            revert Errors.TradeSizeTooSmall();
        }
    }

    /// @notice Updates the market's funding values.
    /// @param self The PerpMarket storage pointer.
    /// @param fundingRate The market's current funding rate.
    /// @param fundingFeePerUnit The market's current funding fee per unit.
    function updateFunding(Data storage self, SD59x18 fundingRate, SD59x18 fundingFeePerUnit) internal {
        self.lastFundingRate = fundingRate.intoInt256();
        self.lastFundingFeePerUnit = fundingFeePerUnit.intoInt256();
        self.lastFundingTime = block.timestamp;
    }

    /// @notice Updates the market's open interest and skew values.
    /// @param self The PerpMarket storage pointer.
    /// @param newOpenInterest The new open interest value.
    /// @param newSkew The new skew value.
    function updateOpenInterest(Data storage self, UD60x18 newOpenInterest, SD59x18 newSkew) internal {
        self.skew = newSkew.intoInt256().toInt128();
        self.openInterest = newOpenInterest.intoUint128();
    }

    /// @param marketId The perp market id.
    /// @param name The perp market name.
    /// @param symbol The perp market symbol.
    /// @param priceAdapter The price oracle contract address.
    /// @param initialMarginRateX18 The initial margin rate in 1e18.
    /// @param maintenanceMarginRateX18 The maintenance margin rate in 1e18.
    /// @param maxOpenInterest The maximum open interest allowed.
    /// @param maxSkew The maximum skew allowed.
    /// @param maxFundingVelocity The maximum funding velocity allowed.
    /// @param minTradeSizeX18 The minimum trade size in 1e18.
    /// @param skewScale The skew scale, a configurable parameter that determines price marking and funding.
    /// @param marketOrderConfiguration The market order configuration.
    /// @param customOrdersConfiguration The custom orders configuration.
    /// @param orderFees The configured maker and taker order fee tiers.
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

    /// @notice Creates a new PerpMarket.
    /// @dev See {CreateParams}.
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
