// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Math } from "@zaros/utils/Math.sol";
import { Distribution } from "./Distribution.sol";

// Open Zeppelin dependencies
import { EnumerableMap } from "@openzeppelin/utils/structs/EnumerableMap.sol";
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18 } from "@prb-math/SD59x18.sol";

/// @dev NOTE: realized debt -> unsettled debt -> settled debt
/// TODO: do we only send realized debt as unsettled debt to the vaults? should it be considered settled debt? or do
/// we send the entire reported debt as unsettled debt?
library MarketDebt {
    using Distribution for Distribution.Data;
    using EnumerableMap for EnumerableMap.AddressToUintMap;
    using EnumerableSet for EnumerableSet.UintSet;
    using SafeCast for int256;

    /// @notice ERC7201 storage location.
    bytes32 internal constant MARKET_DEBT_LOCATION =
        keccak256(abi.encode(uint256(keccak256("fi.zaros.market-making.MarketDebt")) - 1));

    /// @param marketId The perps engine's linked market id.
    /// @param autoDeleverageStartThreshold An admin configurable decimal rate used to determine the starting
    /// threshold of the ADL polynomial regression curve, ranging from 0 to 1.
    /// @param autoDeleverageEndThreshold An admin configurable decimal rate used to determine the ending threshold of
    /// the ADL polynomial regression curve, ranging from 0 to 1.
    /// @param autoDeleveragePowerScale An admin configurable power scale, used to determine the acceleration of the
    /// ADL polynomial regression curve.
    /// @param openInterestCapScale An admin configurable value which determines the market's open interest cap,
    /// according to the total delegated credit.
    /// @param skewCapScale An admin configurable value which determines the market's skew cap, according to the total
    /// delegated credit.
    /// @param realizedDebtUsd The net delta of USDz minted by the market and margin collateral collected from
    /// traders and converted to USDC or ZLP Vaults assets.
    /// @param lastDistributedRealizedDebtUsd The last realized debt in USD distributed as unsettled debt to connected
    /// vaults.
    /// @param lastDistributedTotalDebtUsd The last total debt in USD distributed as `value` to the vaults debt
    /// distribution.
    /// @param collectedMarginCollateral An enumerable map that stores the amount of each margin collateral asset
    /// collected from perps traders at a market.
    /// @param connectedVaultsIds The list of vaults ids delegating credit to this market. Whenever there's an update,
    /// a new `EnumerableSet.UintSet` is created.
    /// @param vaultsDebtDistribution `actor`: Vaults, `shares`: USD denominated credit delegated, `valuePerShare`:
    /// USD denominated debt per share.
    struct Data {
        uint128 marketId;
        uint128 autoDeleverageStartThreshold;
        uint128 autoDeleverageEndThreshold;
        uint128 autoDeleveragePowerScale;
        uint128 openInterestCapScale;
        uint128 skewCapScale;
        int128 realizedDebtUsd;
        int128 lastDistributedRealizedDebtUsd;
        int128 lastDistributedTotalDebtUsd;
        EnumerableMap.AddressToUintMap collectedMarginCollateral;
        EnumerableSet.UintSet[] connectedVaultsIds;
        Distribution.Data vaultsDebtDistribution;
    }

    /// @notice Loads a {MarketDebt} namespace.
    /// @param marketId The perp market id.
    /// @return marketDebt The loaded market debt storage pointer.
    function load(uint256 marketId) internal pure returns (Data storage marketDebt) {
        bytes32 slot = keccak256(abi.encode(MARKET_DEBT_LOCATION, marketId));
        assembly {
            marketDebt.slot := slot
        }
    }

    /// @notice Updates the market debt's configuration parameters.
    /// @dev See {MarketDebt.Data} for parameters description.
    /// @dev Calls to this function must be protected by an authorization modifier.
    function configure(
        uint128 marketId,
        uint128 autoDeleverageStartThreshold,
        uint128 autoDeleverageEndThreshold,
        uint128 autoDeleveragePowerScale,
        uint128 openInterestCapScale,
        uint128 skewCapScale
    )
        internal
    {
        Data storage self = load(marketId);

        self.marketId = marketId;
        self.autoDeleverageStartThreshold = autoDeleverageStartThreshold;
        self.autoDeleverageEndThreshold = autoDeleverageEndThreshold;
        self.autoDeleveragePowerScale = autoDeleveragePowerScale;
        self.openInterestCapScale = openInterestCapScale;
        self.skewCapScale = skewCapScale;
    }

    /// @notice Computes the auto delevarage factor of the market based on the market's credit capacity, total debt
    /// and its configured ADL parameters.
    /// @dev The auto deleverage factor is the `y` coordinate of the following polynomial regression curve:
    //// X and Y in [0, 1]
    /// y = x^z
    /// z = MarketDebt.Data.autoDeleveragePowerScale
    /// x = (Math.min(marketDebtRatio, autoDeleverageEndThreshold) - autoDeleverageStartThreshold)  /
    /// (autoDeleverageEndThreshold - autoDeleverageStartThreshold)
    /// where:
    /// marketDebtRatio = MarketDebt::getTotalDebt / MarketDebt::getCreditCapacity
    /// @param self The market debt storage pointer.
    /// @return autoDeleverageFactor A decimal rate which determines how much should the market cut of the position's
    /// profit. Goes from 0 to 1.
    function getAutoDeleverageFactor(
        Data storage self,
        UD60x18 creditCapacityUsdX18,
        SD59x18 totalDebtUsdX18
    )
        internal
        view
        returns (UD60x18 autoDeleverageFactor)
    {
        // calculates the market debt ratio
        UD60x18 marketDebtRatio = totalDebtUsdX18.div(creditCapacityUsdX18);

        // cache the auto deleverage parameters as UD60x18
        UD60x18 autoDeleverageStartThresholdX18 = ud60x18(self.autoDeleverageStartThreshold);
        UD60x18 autoDeleverageEndThresholdX18 = ud60x18(self.autoDeleverageEndThreshold);
        UD60x18 autoDeleveragePowerScaleX18 = ud60x18(self.autoDeleveragePowerScale);

        // first, calculate the unscaled delevarage factor
        UD60x18 unscaledDeleverageFactor = Math.min(marketDebtRatio, autoDeleverageEndThresholdX18).sub(
            autoDeleverageStartThresholdX18
        ).div(autoDeleverageEndThresholdX18.sub(autoDeleverageStartThresholdX18));

        // finally, raise to the power scale
        autoDeleverageFactor = unscaledDeleverageFactor.pow(autoDeleveragePowerScaleX18);
    }

    function getConnectedVaultsIds(Data storage self) internal view returns (uint256[] memory connectedVaultsIds) {
        if (self.connectedVaultsIds.length == 0) {
            return connectedVaultsIds;
        }

        connectedVaultsIds = self.connectedVaultsIds[self.connectedVaultsIds.length].values();
    }

    function getCreditCapacity(
        Data storage self,
        UD60x18 delegatedCreditUsdX18
    )
        internal
        view
        returns (SD59x18 creditCapacityUsdX18)
    {
        creditCapacityUsdX18 = delegatedCreditUsdX18.intoSD59x18().add(sd59x18(self.realizedDebtUsd));
    }

    function getDelegatedCredit(Data storage self) internal view returns (UD60x18 totalDelegatedCreditUsdX18) {
        totalDelegatedCreditUsdX18 = ud60x18(self.vaultsDebtDistribution.totalShares);
    }

    function getInRangeVaultsIds(Data storage self) internal returns (uint128[] memory inRangeVaultsIds) { }

    function getMarketCaps(Data storage self)
        internal
        view
        returns (UD60x18 openInterestCapX18, UD60x18 skewCapX18)
    {
        UD60x18 totalDelegatedCredit = ud60x18(self.vaultsDebtDistribution.totalShares);

        openInterestCapX18 = ud60x18(self.openInterestCapScale).mul(totalDelegatedCredit);
        skewCapX18 = ud60x18(self.skewCapScale).mul(totalDelegatedCredit);
    }

    function getTotalDebt(Data storage self) internal view returns (SD59x18 totalDebtUsdX18) { }

    function isAutoDeleverageTriggered(Data storage self, SD59x18 totalDebtUsdX18) internal view returns (bool) { }

    function addMarginCollateral(Data storage self, address collateralType, uint256 amount) internal { }

    // TODO: see how to return the unsettled debt change
    function distributeDebtToVaults(
        Data storage self,
        SD59x18 newTotalDebtUsdX18
    )
        internal
        returns (SD59x18 unsettledDebtChangeUsdX18)
    {
        // loads the vaults debt distribution storage pointer
        Distribution.Data storage vaultsDebtDistribution = self.vaultsDebtDistribution;
        // int128 -> SD59x18
        SD59x18 lastDistributedTotalDebtUsdX18 = sd59x18(self.lastDistributedTotalDebtUsd);

        /// distributes the delta between the last distributed total debt and the new total debt to the vaults and
        /// cache the unsettled debt change in the distribution.
        // NOTE: this unsettled debt value will be further distributed to the vaults in the next iteration at the
        // parent context, which is then settled for USDC by the protocol when applicable.

        vaultsDebtDistribution.distributeValue(lastDistributedTotalDebtUsdX18.sub(newTotalDebtUsdX18));

        // update the last distributed total debt
        self.lastDistributedTotalDebtUsd = newTotalDebtUsdX18.intoInt256().toInt128();
    }

    /// @notice Adds the minted usdz or the margin collateral collected from traders into the stored realized debt.
    /// @param self The market debt storage pointer.
    /// @param debtToRealizeUsdX18 The amount of debt to realize in USD.
    function realizeDebt(Data storage self, SD59x18 debtToRealizeUsdX18) internal {
        self.realizedDebtUsd = sd59x18(self.realizedDebtUsd).add(debtToRealizeUsdX18).intoInt256().toInt128();
    }
}
