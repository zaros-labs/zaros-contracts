// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Math } from "@zaros/utils/Math.sol";
import { IEngine } from "@zaros/market-making/interfaces/IEngine.sol";
import { CreditDeposit } from "@zaros/market-making/leaves/CreditDeposit.sol";
import { Distribution } from "./Distribution.sol";

// Open Zeppelin dependencies
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

// PRB Math dependencies
import { UD60x18, ud60x18, UNIT as UD60x18_UNIT } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18, ZERO as SD59x18_ZERO } from "@prb-math/SD59x18.sol";

/// @dev NOTE: unrealized debt (from market) -> realized debt (market) -> unsettled debt (vaults) -> settled
/// debt (vaults)
/// TODO: do we only send realized debt as unsettled debt to the vaults? should it be considered settled debt? or do
/// we send the entire reported debt as unsettled debt?
library Market {
    using CreditDeposit for CreditDeposit.Data;
    using Distribution for Distribution.Data;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;
    using SafeCast for int256;

    /// @notice ERC7201 storage location.
    bytes32 internal constant MARKET_LOCATION =
        keccak256(abi.encode(uint256(keccak256("fi.zaros.market-making.Market")) - 1));

    /// @notice {Market} namespace storage structure.
    /// @param engine The engine contract address that operates this market id.
    /// @param marketId The engine's linked market id.
    /// @param autoDeleverageStartThreshold An admin configurable decimal rate used to determine the starting
    /// threshold of the ADL polynomial regression curve, ranging from 0 to 1.
    /// @param autoDeleverageEndThreshold An admin configurable decimal rate used to determine the ending threshold of
    /// the ADL polynomial regression curve, ranging from 0 to 1.
    /// @param autoDeleveragePowerScale An admin configurable power scale, used to determine the acceleration of the
    /// ADL polynomial regression curve.
    /// @param realizedUsdzDebt The net value of usdz deposited or withdrawn to / from the market. Used to determine
    /// the total realized debt and the connected vault's unsettled debt.
    /// @param lastDistributedRealizedDebtUsd The last realized debt in USD distributed as unsettled debt to connected
    /// vaults.
    /// @param lastDistributedUnrealizedDebtUsd The last total debt in USD distributed as `value` to the vaults debt
    /// distribution.
    /// @param depositedCollateralTypes Stores the set of addresses of collateral types deposited as credit for a
    /// market.
    /// @param connectedVaultsIds The list of vaults ids delegating credit to this market. Whenever there's an update,
    /// a new `EnumerableSet.UintSet` is created.
    /// @param vaultsDebtDistribution `actor`: Vaults, `shares`: USD denominated credit delegated, `valuePerShare`:
    /// USD denominated debt per share.
    struct Data {
        address engine;
        uint128 marketId;
        uint128 autoDeleverageStartThreshold;
        uint128 autoDeleverageEndThreshold;
        uint128 autoDeleveragePowerScale;
        int128 realizedUsdzDebt;
        int128 lastDistributedRealizedDebtUsd;
        int128 lastDistributedUnrealizedDebtUsd;
        EnumerableSet.AddressSet depositedCollateralTypes;
        EnumerableSet.UintSet[] connectedVaultsIds;
        Distribution.Data vaultsDebtDistribution;
    }

    /// @notice Loads a {Market} namespace.
    /// @param marketId The perp market id.
    /// @return market The loaded market storage pointer.
    function load(uint256 marketId) internal pure returns (Data storage market) {
        bytes32 slot = keccak256(abi.encode(MARKET_LOCATION, marketId));
        assembly {
            market.slot := slot
        }
    }

    /// @notice Updates the market's configuration parameters.
    /// @dev See {Market.Data} for parameters description.
    /// @dev Calls to this function must be protected by an authorization modifier.
    function configure(
        uint128 marketId,
        uint128 autoDeleverageStartThreshold,
        uint128 autoDeleverageEndThreshold,
        uint128 autoDeleveragePowerScale
    )
        internal
    {
        Data storage self = load(marketId);

        self.marketId = marketId;
        self.autoDeleverageStartThreshold = autoDeleverageStartThreshold;
        self.autoDeleverageEndThreshold = autoDeleverageEndThreshold;
        self.autoDeleveragePowerScale = autoDeleveragePowerScale;
    }

    /// @notice Computes the auto delevarage factor of the market based on the market's credit capacity, total debt
    /// and its configured ADL parameters.
    /// @dev The auto deleverage factor is the `y` coordinate of the following polynomial regression curve:
    //// X and Y in [0, 1] ∈ R
    /// y = x^z
    /// z = Market.Data.autoDeleveragePowerScale
    /// x = (Math.min(marketRatio, autoDeleverageEndThreshold) - autoDeleverageStartThreshold)  /
    /// (autoDeleverageEndThreshold - autoDeleverageStartThreshold)
    /// where:
    /// marketRatio = (Market::getUnrealizedDebtUsdX18 + Market.Data.realizedUsdzDebt) /
    /// Market::getCreditCapacityUsd
    /// @param self The market storage pointer.
    /// @param creditCapacityUsdX18 The market's credit capacity in USD.
    /// @param totalDebtUsdX18 The market's total debt in USD, assumed to be positive.
    /// @dev IMPORTANT: This function assumes the market is in net debt. If the market is in net credit,
    /// this function must not be called otherwise it will return an incorrect deleverage factor.
    /// @return autoDeleverageFactorX18 A decimal rate which determines how much should the market cut of the
    /// position's profit. Ranges between 0 and 1.
    function getAutoDeleverageFactor(
        Data storage self,
        SD59x18 creditCapacityUsdX18,
        SD59x18 totalDebtUsdX18
    )
        internal
        view
        returns (UD60x18 autoDeleverageFactorX18)
    {
        if (creditCapacityUsdX18.lte(totalDebtUsdX18) || creditCapacityUsdX18.lte(SD59x18_ZERO)) {
            autoDeleverageFactorX18 = UD60x18_UNIT;
            return autoDeleverageFactorX18;
        }
        // calculates the market ratio
        UD60x18 marketRatio = totalDebtUsdX18.div(creditCapacityUsdX18).intoUD60x18();

        // cache the auto deleverage parameters as UD60x18
        UD60x18 autoDeleverageStartThresholdX18 = ud60x18(self.autoDeleverageStartThreshold);
        UD60x18 autoDeleverageEndThresholdX18 = ud60x18(self.autoDeleverageEndThreshold);
        UD60x18 autoDeleveragePowerScaleX18 = ud60x18(self.autoDeleveragePowerScale);

        // first, calculate the unscaled delevarage factor
        UD60x18 unscaledDeleverageFactor = Math.min(marketRatio, autoDeleverageEndThresholdX18).sub(
            autoDeleverageStartThresholdX18
        ).div(autoDeleverageEndThresholdX18.sub(autoDeleverageStartThresholdX18));

        // finally, raise to the power scale
        autoDeleverageFactorX18 = unscaledDeleverageFactor.pow(autoDeleveragePowerScaleX18);
    }

    function getConnectedVaultsIds(Data storage self) internal view returns (uint256[] memory connectedVaultsIds) {
        if (self.connectedVaultsIds.length == 0) {
            return connectedVaultsIds;
        }

        connectedVaultsIds = self.connectedVaultsIds[self.connectedVaultsIds.length].values();
    }

    function getCreditCapacityUsd(
        UD60x18 delegatedCreditUsdX18,
        SD59x18 unrealizedDebtUsdX18,
        SD59x18 realizedDebtUsdX18
    )
        internal
        view
        returns (SD59x18 creditCapacityUsdX18)
    {
        creditCapacityUsdX18 = delegatedCreditUsdX18.intoSD59x18().add(unrealizedDebtUsdX18).add(realizedDebtUsdX18);
    }

    function getDelegatedCredit(Data storage self) internal view returns (UD60x18 totalDelegatedCreditUsdX18) {
        totalDelegatedCreditUsdX18 = ud60x18(self.vaultsDebtDistribution.totalShares);
    }

    function getInRangeVaultsIds(Data storage self) internal returns (uint128[] memory inRangeVaultsIds) { }

    // TODO: iterate over each collateral deposit + realized usdz debt
    function getRealizedDebtUsd(Data storage self) internal view returns (SD59x18 realizedDebtUsdX18) { }

    function getUnrealizedDebtUsd(Data storage self) internal view returns (SD59x18 unrealizedDebtUsdX18) {
        unrealizedDebtUsdX18 = sd59x18(IEngine(self.engine).getUnrealizedDebt(self.marketId));
    }

    function isAutoDeleverageTriggered(Data storage self, SD59x18 totalDebtUsdX18) internal view returns (bool) { }

    /// @notice Deposits collateral to the market as credit.
    /// @dev This function assumes the collateral type address is configured in the protocol and has been previously
    /// verified.
    function depositCollateral(Data storage self, address collateralType, UD60x18 amountX18) internal {
        EnumerableSet.AddressSet storage depositedCollateralTypes = self.depositedCollateralTypes;

        // adds the collateral type address to the address set if it's not already there
        // NOTE: we don't need to check with `EnumerableSet::contains` as the following function already performs this
        depositedCollateralTypes.add(collateralType);

        // loads the credit deposit storage pointer
        CreditDeposit.Data storage creditDeposit = CreditDeposit.load(self.marketId, collateralType);
        // adds the amount of deposited collateral
        creditDeposit.add(amountX18);
    }

    // TODO: after this function is called we need to update a vault's realized unsettled debt
    // todo: update realized debt usd logic
    function distributeDebtToVaults(
        Data storage self,
        SD59x18 newUnrealizedDebtUsdX18,
        SD59x18 newRealizedDebtUsdX18
    )
        internal
    {
        // int128 -> SD59x18
        SD59x18 lastDistributedUnrealizedDebtUsdX18 = sd59x18(self.lastDistributedUnrealizedDebtUsd);
        // int128 -> SD59x18
        SD59x18 lastDistributedRealizedDebtUsdX18 = sd59x18(self.lastDistributedRealizedDebtUsd);

        // caches the new realized debt value to be stored
        int128 newRealizedDebtUsd = sd59x18(self.realizedUsdzDebt).add(debtToRealizeUsdX18).intoInt256().toInt128();

        // update storage values
        self.realizedUsdzDebt = newRealizedDebtUsd;
        self.lastDistributedRealizedDebtUsd = newRealizedDebtUsd;
        self.lastDistributedUnrealizedDebtUsd = newUnrealizedDebtUsdX18.intoInt256().toInt128();

        // loads the vaults debt distribution storage pointer
        Distribution.Data storage vaultsDebtDistribution = self.vaultsDebtDistribution;

        // The debt to be distributed takes into account the diff between the last and the new unrealized debt, and
        // sums with the diff between the last and new realized debt, taking into account the additional debt that is
        // being realized in the current execution context.
        SD59x18 distributedDebtUsdX18 = newUnrealizedDebtUsdX18.sub(lastDistributedUnrealizedDebtUsdX18).add(
            sd59x18(newRealizedDebtUsd).sub(lastDistributedRealizedDebtUsdX18)
        );

        // distributes debt as value to the vaults debt distribution
        // NOTE: distributed debt must be further pushed down the debt distribution system in order to keep the
        // system accounting valid.
        vaultsDebtDistribution.distributeValue(distributedDebtUsdX18);
    }

    /// @notice Adds the minted usdz or the margin collateral collected from traders into the stored realized debt.
    /// @param self The market storage pointer.
    /// @param debtToRealizeUsdX18 The amount of debt to realize in USD.
    function realizeDebt(Data storage self, SD59x18 debtToRealizeUsdX18) internal {
        self.realizedUsdzDebt = sd59x18(self.realizedUsdzDebt).add(debtToRealizeUsdX18).intoInt256().toInt128();
    }

    function recalculateDelegatedCredit(Data storage self) internal { }
}
