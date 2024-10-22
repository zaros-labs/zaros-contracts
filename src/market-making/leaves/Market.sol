// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Math } from "@zaros/utils/Math.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { IEngine } from "@zaros/market-making/interfaces/IEngine.sol";
import { Collateral } from "@zaros/market-making/leaves/Collateral.sol";
import { CreditDeposit } from "@zaros/market-making/leaves/CreditDeposit.sol";
import { Distribution } from "./Distribution.sol";

// Open Zeppelin dependencies
import { EnumerableMap } from "@openzeppelin/utils/structs/EnumerableMap.sol";
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

// PRB Math dependencies
import { UD60x18, ud60x18, UNIT as UD60x18_UNIT } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18 } from "@prb-math/SD59x18.sol";

/// @dev NOTE: unrealized debt (from market) -> realized debt (market) -> unsettled debt (vaults) -> settled
/// debt (vaults)'
/// todo: create and update functions
// todo: next, review market's and vault's updated natspec and finish removing old flow functions to wrap up the new
// flow.
library Market {
    using Collateral for Collateral.Data;
    using CreditDeposit for CreditDeposit.Data;
    using Distribution for Distribution.Data;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableMap for EnumerableMap.AddressToUintMap;
    using SafeCast for int256;
    using SafeCast for uint256;

    /// @notice ERC7201 storage location.
    /// todo: create VaultService and MarketService
    bytes32 internal constant MARKET_LOCATION =
        keccak256(abi.encode(uint256(keccak256("fi.zaros.market-making.Market")) - 1));

    /// @notice {Market} namespace storage structure.
    /// @param id The market identifier, must be the same one stored in the Market Making Engine and in its connected
    /// engine.
    /// @param autoDeleverageStartThreshold An admin configurable decimal rate used to determine the starting
    /// threshold of the ADL polynomial regression curve, ranging from 0 to 1.
    /// @param autoDeleverageEndThreshold An admin configurable decimal rate used to determine the ending threshold of
    /// the ADL polynomial regression curve, ranging from 0 to 1.
    /// @param autoDeleveragePowerScale An admin configurable exponent used to determine the acceleration of the
    /// ADL polynomial regression curve.
    /// @param marketShare The share of total accumulated weth to be allocated to the market. Example: 0.5e18 (50%).
    /// @param feeRecipientsShare The share of total accumulated weth to be allocated to fee recipients.Example:
    /// 0.5e18 (50%).
    /// @param realizedDebtUsd Stores the market's latest realized debt value in USD, taking into account usd tokens
    /// that have been directly minted or burned by the market's engine, and the net sum of all credit deposits.
    /// @param lastDistributedRealizedDebtUsd The last realized debt in USD distributed as unsettled debt to connected
    /// vaults.
    /// @param lastDistributedUnrealizedDebtUsd The last unrealized debt in USD distributed as `value` to the vaults
    /// debt distribution.
    /// @param totalWethReward The total amount of weth rewards accumulated by the market, paid by its engine.
    /// @param isLive Whether the market is currently live or paused.
    /// @param engine The address of the market's connected engine, used to fetch the market's unrealized debt and
    /// system validations.
    /// @param depositedCollateralTypes Stores the set of addresses of collateral assets used for credit deposits to a
    /// market.
    /// @param connectedVaults The list of vaults ids delegating credit to this market. Whenever there's an update,
    /// a new `EnumerableSet.UintSet` is created.
    /// @param receivedMarketFees An enumerable map that stores the amounts collected from each collateral type
    /// available to convert to weth.
    /// @param vaultsDebtDistribution `actor`: Vaults, `shares`: USD denominated credit delegated,
    /// `valuePerShare`: USD denominated market debt or credit per share.
    struct Data {
        uint128 id;
        uint128 autoDeleverageStartThreshold;
        uint128 autoDeleverageEndThreshold;
        uint128 autoDeleveragePowerScale;
        uint128 marketShare;
        uint128 feeRecipientsShare;
        int128 realizedDebtUsd;
        uint128 lastRealizedDebtUpdateTime;
        int128 lastDistributedRealizedDebtUsd;
        int128 lastDistributedUnrealizedDebtUsd;
        uint128 totalWethReward;
        address engine;
        bool isLive;
        EnumerableSet.AddressSet depositedCollateralTypes;
        EnumerableSet.UintSet[] connectedVaults;
        EnumerableMap.AddressToUintMap receivedMarketFees;
        Distribution.Data vaultsDebtDistribution;
    }

    /// @notice Loads a {Market} namespace.
    /// @param marketId The perp market id.
    /// @return market The loaded market storage pointer.
    function load(uint128 marketId) internal pure returns (Data storage market) {
        bytes32 slot = keccak256(abi.encode(MARKET_LOCATION, marketId));
        assembly {
            market.slot := slot
        }
    }

    /// @notice Loads a {Market} namespace.
    /// @dev Invariants:
    /// The Market MUST exist.
    /// @param marketId The perp market id.
    /// @return market The loaded market storage pointer.
    function loadExisting(uint128 marketId) internal view returns (Data storage market) {
        market = load(marketId);

        if (market.id == 0) {
            revert Errors.MarketDoesNotExist(marketId);
        }
    }

    /// @notice Loads a {Market} namespace.
    /// @dev Invariants:
    /// The Market MUST exist.
    /// The Market MUST be live.
    /// @param marketId The perp market id.
    /// @return market The loaded market storage pointer.
    function loadLive(uint128 marketId) internal view returns (Data storage market) {
        market = loadExisting(marketId);

        if (!market.isLive) {
            revert Errors.MarketIsDisabled(marketId);
        }
    }

    /// @notice Computes the auto delevarage factor of the market based on the market's credit capacity, total debt
    /// and its configured ADL parameters.
    /// @dev The auto deleverage factor is the `y` coordinate of the following polynomial regression curve:
    //// X and Y in [0, 1] ∈ R
    /// y = x^z
    /// z = Market.Data.autoDeleveragePowerScale
    /// x = (Math.min(marketDebtRatio, autoDeleverageEndThreshold) - autoDeleverageStartThreshold)  /
    /// (autoDeleverageEndThreshold - autoDeleverageStartThreshold)
    /// where:
    /// marketDebtRatio = (Market::getUnrealizedDebtUsdX18 + Market.Data.realizedDebtUsd) /
    /// Market::getCreditCapacityUsd
    /// @param self The market storage pointer.
    /// @param delegatedCreditUsdX18 The market's credit delegated by vaults in USD, used to determine the ADL state.
    /// @param totalDebtUsdX18 The market's total debt in USD, assumed to be positive.
    /// @dev IMPORTANT: This function assumes the market is in net debt. If the market is in net credit,
    /// this function must not be called otherwise it will return an incorrect deleverage factor.
    /// @return autoDeleverageFactorX18 A decimal rate which determines how much should the market cut of the
    /// position's profit. Ranges between 0 and 1.
    function getAutoDeleverageFactor(
        Data storage self,
        UD60x18 delegatedCreditUsdX18,
        SD59x18 totalDebtUsdX18
    )
        internal
        view
        returns (UD60x18 autoDeleverageFactorX18)
    {
        SD59x18 sdDelegatedCreditUsdX18 = delegatedCreditUsdX18.intoSD59x18();
        if (sdDelegatedCreditUsdX18.lte(totalDebtUsdX18) || sdDelegatedCreditUsdX18.isZero()) {
            autoDeleverageFactorX18 = UD60x18_UNIT;
            return autoDeleverageFactorX18;
        }
        // calculates the market ratio
        UD60x18 marketDebtRatio = totalDebtUsdX18.div(sdDelegatedCreditUsdX18).intoUD60x18();

        // cache the auto deleverage parameters as UD60x18
        UD60x18 autoDeleverageStartThresholdX18 = ud60x18(self.autoDeleverageStartThreshold);
        UD60x18 autoDeleverageEndThresholdX18 = ud60x18(self.autoDeleverageEndThreshold);
        UD60x18 autoDeleveragePowerScaleX18 = ud60x18(self.autoDeleveragePowerScale);

        // first, calculate the unscaled delevarage factor
        UD60x18 unscaledDeleverageFactor = Math.min(marketDebtRatio, autoDeleverageEndThresholdX18).sub(
            autoDeleverageStartThresholdX18
        ).div(autoDeleverageEndThresholdX18.sub(autoDeleverageStartThresholdX18));

        // finally, raise to the power scale
        autoDeleverageFactorX18 = unscaledDeleverageFactor.pow(autoDeleveragePowerScaleX18);
    }

    /// @notice Returns a memory array containing the vaults delegating credit to the market.
    /// @param self The market storage pointer.
    /// @return connectedVaults The vaults ids delegating credit to the market.
    function getConnectedVaultsIds(Data storage self) internal view returns (uint256[] memory connectedVaults) {
        if (self.connectedVaults.length == 0) {
            return connectedVaults;
        }

        connectedVaults = self.connectedVaults[self.connectedVaults.length].values();
    }

    /// @notice Returns a market's credit capacity in USD based on its delegated credit and total debt.
    /// @param delegatedCreditUsdX18 The market's credit delegated by vaults in USD.
    /// @param totalDebtUsdX18 The market's unrealized + realized debt in USD.
    /// @return creditCapacityUsdX18 The market's credit capacity in USD.
    function getCreditCapacityUsd(
        UD60x18 delegatedCreditUsdX18,
        SD59x18 totalDebtUsdX18
    )
        internal
        pure
        returns (SD59x18 creditCapacityUsdX18)
    {
        creditCapacityUsdX18 = delegatedCreditUsdX18.intoSD59x18().add(totalDebtUsdX18);
    }

    /// @notice Returns all the credit delegated by the vaults connected to the market.
    /// @param self The market storage pointer.
    /// @return totalDelegatedCreditUsdX18 The total credit delegated by the vaults in USD.
    function getTotalDelegatedCreditUsd(Data storage self)
        internal
        view
        returns (UD60x18 totalDelegatedCreditUsdX18)
    {
        // the market's total delegated credit equals the total shares of the vaults debt distribution, as 1 share
        // equals 1 USD of vault-delegated credit
        totalDelegatedCreditUsdX18 = ud60x18(self.vaultsDebtDistribution.totalShares);
    }

    // todo: see if this function will be actually needed
    function getInRangeVaultsIds(Data storage self) internal returns (uint128[] memory inRangeVaultsIds) { }

    /// @notice Returns the market's realized debt in USD.
    /// @dev `updateRealizedDebt` uses this method to update the stored value and the last update timestamp.
    /// @param self The market storage pointer.
    /// @return realizedDebtUsdX18 The market's total realized debt in USD.
    function getRealizedDebtUsd(Data storage self) internal view returns (SD59x18 realizedDebtUsdX18) {
        // if the realized debt is up to date, return the stored value
        if (block.timestamp <= self.lastRealizedDebtUpdateTime) {
            return sd59x18(self.realizedDebtUsd);
        }
        // otherwise, we'll need to recalculate the realized debt value

        // load the deposited collateral types address set storage pointer
        EnumerableSet.AddressSet storage depositedCollateralTypes = self.depositedCollateralTypes;

        for (uint256 i; i < depositedCollateralTypes.length(); i++) {
            address collateralType = depositedCollateralTypes.at(i);
            // load the configured collateral type storage pointer
            Collateral.Data storage collateral = Collateral.load(collateralType);
            // load the credit deposit storage pointer
            CreditDeposit.Data storage creditDeposit = CreditDeposit.load(self.id, collateralType);

            // add the credit deposit usd value to the realized debt return value
            realizedDebtUsdX18 = realizedDebtUsdX18.add(
                (collateral.getAdjustedPrice().mul(ud60x18(creditDeposit.value))).intoSD59x18()
            );
        }

        // finally after looping over the credit deposits, add the realized usdToken debt to the realized debt to be
        // returned
        realizedDebtUsdX18 = realizedDebtUsdX18.add(sd59x18(self.realizedDebtUsd));
    }

    /// @notice Returns the credit delegated by a vault to the market in USD.
    /// @dev A vault's usd credit delegated to the market is represented by its shares in the
    /// `Market.Data.vaultsDebtDistribution`.
    /// @param self The market storage pointer.
    /// @param vaultId The id of the vault to get the delegated credit from.
    /// @return vaultDelegatedCreditUsdX18 The vault's delegated credit in USD.
    function getVaultDelegatedCreditUsd(
        Data storage self,
        uint128 vaultId
    )
        internal
        view
        returns (UD60x18 vaultDelegatedCreditUsdX18)
    {
        // loads the vaults unrealized debt distribution storage pointer
        Distribution.Data storage vaultsDebtDistribution = self.vaultsDebtDistribution;
        // uint128 -> bytes32
        bytes32 actorId = bytes32(uint256(vaultId));

        // gets the vault's delegated credit in USD as its distribution shares
        vaultDelegatedCreditUsdX18 = vaultsDebtDistribution.getActorShares(actorId);
    }

    /// @notice Returns the market's total unrealized debt in USD.
    /// @dev This function assumes that the `IEngine::getUnrealizedDebt` function is trusted and returns the accurate
    /// unrealized debt value of the given market id.
    /// @param self The market storage pointer.
    /// @return unrealizedDebtUsdX18 The market's total unrealized debt in USD.
    function getUnrealizedDebtUsd(Data storage self) internal view returns (SD59x18 unrealizedDebtUsdX18) {
        unrealizedDebtUsdX18 = sd59x18(IEngine(self.engine).getUnrealizedDebt(self.id));
    }

    /// @notice Returns whether the market has reached the auto deleverage start threshold, i.e, if the ADL system
    /// must be triggered or not.
    /// @param self The market storage pointer.
    /// @param delegatedCreditUsdX18 The market's credit delegated by vaults in USD, used to determine the ADL state.
    /// @param totalDebtUsdX18 The market's total debt in USD, used to determine the ADL state.
    function isAutoDeleverageTriggered(
        Data storage self,
        UD60x18 delegatedCreditUsdX18,
        SD59x18 totalDebtUsdX18
    )
        internal
        view
        returns (bool)
    {
        SD59x18 sdDelegatedCreditUsdX18 = delegatedCreditUsdX18.intoSD59x18();
        if (sdDelegatedCreditUsdX18.lte(totalDebtUsdX18) || sdDelegatedCreditUsdX18.isZero()) {
            return false;
        }
        // calculates the market ratio
        UD60x18 marketDebtRatio = totalDebtUsdX18.div(sdDelegatedCreditUsdX18).intoUD60x18();

        // cache the auto deleverage parameters as UD60x18
        UD60x18 autoDeleverageStartThresholdX18 = ud60x18(self.autoDeleverageStartThreshold);

        return marketDebtRatio.gte(autoDeleverageStartThresholdX18);
    }

    /// @notice Returns whether the market's realized debt value is outdated or not.
    /// @dev Functions that require the updated market realized debt value must use this method to understand whether
    /// they should call `getRealizedDebtUsd`, which is an expensive operation, o
    function isRealizedDebtUpdateRequired(Data storage self) internal view returns (bool) {
        return block.timestamp > self.lastRealizedDebtUpdateTime;
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

        self.id = marketId;
        self.autoDeleverageStartThreshold = autoDeleverageStartThreshold;
        self.autoDeleverageEndThreshold = autoDeleverageEndThreshold;
        self.autoDeleveragePowerScale = autoDeleveragePowerScale;
    }

    /// @notice Configures the vaults ids delegating credit to the market.
    /// @dev This function assumes the vaults ids are unique and have been previously verified.
    /// @param self The market storage pointer.
    /// @param vaultsIds The vaults ids to connect to the market.
    function configureConnectedVaults(Data storage self, uint128[] memory vaultsIds) internal {
        EnumerableSet.UintSet[] storage connectedVaults = self.connectedVaults;

        // add the vauls ids to a new UintSet instance in the connectedVaults array
        for (uint256 i = 0; i < vaultsIds.length; i++) {
            connectedVaults[connectedVaults.length].add(vaultsIds[i]);
        }
    }

    /// @notice Deposits collateral to the market as credit.
    /// @dev This function assumes the collateral type address is configured in the protocol and has been previously
    /// verified.
    /// @param self The market storage pointer.
    /// @param collateralType The address of the collateral type to deposit.
    /// @param amountX18 The amount of collateral to deposit in the market in 18 decimals.
    function depositCollateral(Data storage self, address collateralType, UD60x18 amountX18) internal {
        EnumerableSet.AddressSet storage depositedCollateralTypes = self.depositedCollateralTypes;

        // adds the collateral type address to the address set if it's not already there
        // NOTE: we don't need to check with `EnumerableSet::contains` as the following function already performs this
        depositedCollateralTypes.add(collateralType);

        // loads the credit deposit storage pointer
        CreditDeposit.Data storage creditDeposit = CreditDeposit.load(self.id, collateralType);
        // adds the amount of deposited collateral
        creditDeposit.add(amountX18);
    }

    /// @notice Distributes the market's unrealized and realized debt to the connected vaults.
    /// @dev `Market::accumulateVaultDebt` must be called after this function to update the vault's owned unrealized
    /// and realized credit or debt.
    /// @param self The market storage pointer.
    /// @param newUnrealizedDebtUsdX18 The latest unrealized debt in USD.
    /// @param newRealizedDebtUsdX18 The latest realized debt in USD.
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

        // update storage values
        self.lastDistributedRealizedDebtUsd = newRealizedDebtUsdX18.intoInt256().toInt128();
        self.lastDistributedUnrealizedDebtUsd = newUnrealizedDebtUsdX18.intoInt256().toInt128();

        // loads the vaults unrealized and realized debt distributions storage pointers
        Distribution.Data storage vaultsDebtDistribution = self.vaultsDebtDistribution;

        // stores the return values representing the unrealized and realized debt fluctuations
        SD59x18 unrealizedDebtChangeUsdX18 = newUnrealizedDebtUsdX18.sub(lastDistributedUnrealizedDebtUsdX18);
        SD59x18 realizedDebtChangeUsdX18 = newRealizedDebtUsdX18.sub(lastDistributedRealizedDebtUsdX18);
        SD59x18 totalDebtUsdX18 = unrealizedDebtChangeUsdX18.add(realizedDebtChangeUsdX18);

        // distributes the unrealized and realized debt as value to each vaults debt distribution
        // NOTE: Each vault will need to call `Distribution::accumulateActor` through
        // `Market::accumulateVaultDebt`, and use the return values from that function to update its owned
        // unrealized and realized debt storage values.
        vaultsDebtDistribution.distributeValue(totalDebtUsdX18);
    }

    /// @notice Accumulates a vault's share of the market's unrealized and realized debt since the last distribution,
    /// and calculates the vault's debt changes in USD.
    /// @param self The market storage pointer.
    /// @param vaultId The vault id to accumulate the debt for.
    /// @param lastVaultDistributedWethRewardX18 The last distributed WETH reward for the given credit delegation (by
    /// the vault).
    /// @param lastVaultDistributedUnrealizedDebtUsdX18 The last distributed unrealized debt in USD for the given
    /// credit delegation (by the vault).
    /// @param lastVaultDistributedRealizedDebtUsdX18 The last distributed realized debt in USD for the given credit
    /// delegation (by the vault).
    function accumulateVaultDebtAndReward(
        Data storage self,
        uint128 vaultId,
        UD60x18 lastVaultDistributedWethRewardX18,
        SD59x18 lastVaultDistributedUnrealizedDebtUsdX18,
        SD59x18 lastVaultDistributedRealizedDebtUsdX18
    )
        internal
        returns (UD60x18 wethRewardChangeX18, SD59x18 unrealizedDebtChangeUsdX18, SD59x18 realizedDebtChangeUsdX18)
    {
        // loads the vaults unrealized debt distribution storage pointer
        Distribution.Data storage vaultsDebtDistribution = self.vaultsDebtDistribution;

        // uint128 -> bytes32
        bytes32 actorId = bytes32(uint256(vaultId));
        // calculate the given vault's ratio of the total delegated credit => actor shares / distribution total
        // shares => then convert it to SD59x18
        // NOTE: `div` rounds down by default, which would lead to a small loss to vaults in a
        // credit state, but a small gain in a debt state. We assume this behavior to be negligible in the protocol's
        // context since the diff is minimal and there are risk parameters ensuring debt settlement happens in a
        // timely manner.
        UD60x18 vaultCreditRatioX18 =
            vaultsDebtDistribution.getActorShares(actorId).div(ud60x18(vaultsDebtDistribution.totalShares));

        // accumulates the vault's share of the market's total weth reward since the last interaction
        wethRewardChangeX18 =
            vaultCreditRatioX18.mul(lastVaultDistributedWethRewardX18.sub(ud60x18(self.totalWethReward)));

        // cache UD60x18 -> SD59x18 for gas savings
        SD59x18 vaultCreditRatioSdX18 = vaultCreditRatioX18.intoSD59x18();

        // accumulates the vault's share of the debt since the last distribution, ignoring the return value as it's
        // not needed in this context
        vaultsDebtDistribution.accumulateActor(actorId);
        // multiplies the vault's credit ratio by the change of the market's unrealized debt since the last
        // distribution to determine its share of the unrealized debt change
        unrealizedDebtChangeUsdX18 = vaultCreditRatioSdX18.mul(
            lastVaultDistributedUnrealizedDebtUsdX18.sub(sd59x18(self.lastDistributedUnrealizedDebtUsd))
        );
        // multiplies the vault's credit ratio by the change of the market's realized debt since the last
        // distribution to determine its share of the realized debt change
        realizedDebtChangeUsdX18 = vaultCreditRatioSdX18.mul(
            lastVaultDistributedRealizedDebtUsdX18.sub(sd59x18(self.lastDistributedRealizedDebtUsd))
        );
    }

    /// @notice Realizes the minted or burned usdToken debt updating the market's realized debt value.
    /// @param self The market storage pointer.
    /// @param debtToRealizeUsdX18 The amount of debt to realize in USD.
    function realizeUsdTokenDebt(Data storage self, SD59x18 debtToRealizeUsdX18) internal {
        self.realizedDebtUsd = sd59x18(self.realizedDebtUsd).add(debtToRealizeUsdX18).intoInt256().toInt128();
    }

    /// @notice Updates the market's realized debt usd value by taking into account the market's credit deposits.
    /// @dev If this function is called when a market doesn't need to update its realized debt, it will still work as
    /// `getRealizedDebtUsd` will simply return the stored value, but we want to avoid this scenario to avoid wasting
    /// gas.
    /// @param self The market storage pointer.
    /// @return marketRealizedDebtUsdX18 The market's total realized debt in USD.
    function updateRealizedDebt(Data storage self) internal returns (SD59x18 marketRealizedDebtUsdX18) {
        marketRealizedDebtUsdX18 = getRealizedDebtUsd(self);
        self.realizedDebtUsd = marketRealizedDebtUsdX18.intoInt256().toInt128();
        self.lastRealizedDebtUpdateTime = block.timestamp.toUint128();
    }

    /// @notice Updates a vault's credit delegation to a market, updating each vault's unrealized and realized debt
    /// distributions.
    /// @dev These functions interacting with `Distribution` pointers serve as helpers to avoid external contracts or
    /// libraries to incorrectly handle state updates, as there are insensitive invariants involved, mainly having to
    /// enforce that the vault's shares and the distribution's total shares are always equal.
    /// @param self The market storage pointer.
    /// @param vaultId The vault id to update have its credit delegation shares updated.
    /// @param creditDelegationChangeUsdX18 The USD change of the vault's credit delegation to the market.
    function updateVaultCreditDelegation(
        Data storage self,
        uint128 vaultId,
        UD60x18 newCreditDelegationUsdX18
    )
        internal
        returns (SD59x18 creditDelegationChangeUsdX18)
    {
        // loads the vaults debt distribution storage pointers
        Distribution.Data storage vaultsDebtDistribution = self.vaultsDebtDistribution;

        // uint128 -> bytes32
        bytes32 actorId = bytes32(uint256(vaultId));

        // updates the vault's credit delegation in USD in both distributions as its shares MUST always be equal,
        // otherwise the system will produce unexpected outputs.
        creditDelegationChangeUsdX18 = vaultsDebtDistribution.setActorShares(actorId, newCreditDelegationUsdX18);
    }

    /// @notice Support function to increment the received fees for a specific asset
    /// @param self The fee storage pointer
    /// @param asset The asset address
    /// @param amountX18 The amount to be incremented
    function incrementReceivedMarketFees(Data storage self, address asset, UD60x18 amountX18) internal {
        // declare newAmount variable
        UD60x18 newAmount;

        // check if the asset is already in the receivedMarketFees map
        if (self.receivedMarketFees.contains(asset)) {
            // if it is, increment the amount
            newAmount = amountX18.add(ud60x18(self.receivedMarketFees.get(asset)));
        } else {
            // if it's not, set the amount
            newAmount = amountX18;
        }

        // set the new amount in the receivedMarketFees map
        self.receivedMarketFees.set(asset, newAmount.intoUint256());
    }

    /// @notice Support function to calculate the accumulated wEth allocated for the beneficiary
    /// @param totalAmountX18 The total amount or value to be distributed
    /// @param shareX18 The share that needs to be calculated
    /// @param denominatorX18 The denominator representing the total divisions or base value
    /// @return amountX18 The calculated amount to be distributed
    function calculateFees(
        UD60x18 totalAmountX18,
        UD60x18 shareX18,
        UD60x18 denominatorX18
    )
        internal
        pure
        returns (UD60x18 amountX18)
    {
        amountX18 = (totalAmountX18.mul(shareX18)).div(denominatorX18);
    }
}
