// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { AssetToAmountMap } from "@zaros/utils/libraries/AssetToAmountMap.sol";
import { Math } from "@zaros/utils/Math.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { IEngine } from "@zaros/market-making/interfaces/IEngine.sol";
import { Collateral } from "@zaros/market-making/leaves/Collateral.sol";
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
    /// @param netUsdTokenIssuance The net value of usd tokens minted and burned by this market, mints add while burns
    /// subtract from this variable.
    /// that have been directly minted or burned by the market's engine, and the net sum of all credit deposits.
    /// @param creditDepositsValueCacheUsd The last USD value that accounts for the sum of all credit deposited by the
    /// engine to this market in form of `n` assets.
    /// @param lastCreditDepositsValueRehydration The last timestamp where `creditDepositsValueCacheUsd` has been
    /// updated, avoids wasting gas.
    /// @param realizedDebtUsdPerVaultShare The market's latest net realized debt per vault delegated credit (share)
    /// in USD.
    /// @param unrealizedDebtUsdPerVaultShare The market's latest net unrealized debt per vault delegated credit
    /// (share) in USD.
    /// NOTE: The next three variables use 18 decimals to account for USDC credit and WETH reward per share values.
    /// @param usdcCreditPerVaultShare The amount of usdc credit accumulated by the market per vault delegated credit
    /// (share), using assets deposited by its engine as credit which are at some point swapped for USDC.
    /// @param wethRewardPerVaultShare The  amount of weth reward accumulated by the market per vault delegated credit
    /// (share).
    /// @param availableProtocolWethReward The amount of weth available to be sent to the protocol fee recipients.
    /// @param totalDelegatedCreditUsd The total credit delegated by connected vaults in USD, using 18 decimals.
    /// @param engine The address of the market's connected engine.
    /// @param isLive Whether the market is currently live or paused.
    /// @param creditDeposits The map that stores the amount of collateral assets deposited in the market as credit.
    /// @param connectedVaults The list of vaults ids delegating credit to this market. Whenever there's an update,
    /// a new `EnumerableSet.UintSet` is created.
    /// @param receivedFees An enumerable map that stores the amount of fees received from the engine per asset,
    /// available to be converted to weth.
    struct Data {
        uint128 id;
        uint128 autoDeleverageStartThreshold;
        uint128 autoDeleverageEndThreshold;
        uint128 autoDeleveragePowerScale;
        int128 netUsdTokenIssuance;
        uint128 creditDepositsValueCacheUsd;
        uint128 lastCreditDepositsValueRehydration;
        int128 realizedDebtUsdPerVaultShare;
        int128 unrealizedDebtUsdPerVaultShare;
        uint128 usdcCreditPerVaultShare;
        uint128 wethRewardPerVaultShare;
        uint128 availableProtocolWethReward;
        uint128 totalDelegatedCreditUsd;
        address engine;
        bool isLive;
        EnumerableMap.AddressToUintMap receivedFees;
        EnumerableMap.AddressToUintMap creditDeposits;
        EnumerableSet.UintSet[] connectedVaults;
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
    /// marketDebtRatio = (Market::getUnrealizedDebtUsdX18 + Market.Data.realizedUsdTokenDebt) /
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
        totalDelegatedCreditUsdX18 = ud60x18(self.totalDelegatedCreditUsd);
    }

    /// @notice Loops over each credit deposit made by the market's engine and calculates the net usd value of all
    /// underlying assets summed.
    /// @param self The market storage pointer.
    /// @return creditDepositsValueUsdX18 The 18 decimals, USD value of all credit deposits summed.
    function getCreditDepositsValueUsd(Data storage self) internal view returns (UD60x18 creditDepositsValueUsdX18) {
        // load the map of credit deposits' pointer
        EnumerableMap.AddressToUintMap storage creditDeposits = self.creditDeposits;

        for (uint256 i; i < creditDeposits.length(); i++) {
            // load the credit deposit data
            (address asset, uint256 value) = creditDeposits.at(i);
            // load the configured collateral type storage pointer
            Collateral.Data storage collateral = Collateral.load(asset);

            // update the total credit deposits value
            creditDepositsValueUsdX18 =
                creditDepositsValueUsdX18.add((collateral.getAdjustedPrice().mul(ud60x18(value))).intoSD59x18());
        }
    }

    /// @notice Returns the market's net realized debt in USD.
    /// @param self The market storage pointer.
    /// @return realizedDebtUsdX18 The market's net realized debt in USD as SD59x18.
    function getRealizedDebtUsd(Data storage self) internal view returns (SD59x18 realizedDebtUsdX18) {
        // prepare the credit deposits usd value variable;
        UD60x18 creditDepositsValueUsdX18;

        // if the credit deposits usd value cache is up to date, return the stored value
        if (block.timestamp <= self.lastCreditDepositsValueRehydration) {
            creditDepositsValueUsdX18 = ud60x18(self.creditDepositsValueCacheUsd);
        } else {
            // otherwise, we'll need to loop over credit deposits to calculate it
            creditDepositsValueUsdX18 = getCreditDepositsValueUsd(self);
        }

        // finally after determining the market's latest credit deposits usd value, sum it with the stored net usd
        // token issuance to return the net realized debt usd value
        realizedDebtUsdX18 = realizedDebtUsdX18.add(sd59x18(self.netUsdTokenIssuance));
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

    /// @notice Returns whether the market's credit deposits value cache needs to be rehydrated.
    /// @dev Caching the credit deposits value will save gas in some cases by avoiding looping multiple times over the
    /// credit deposits map, as assets backing those deposits are volatile.
    /// @dev It's assumed that assets' oracle prices are always equal in a same `block.timestamp`.
    function shouldRehydrateCreditDepositsValueCache(Data storage self) internal view returns (bool) {
        return block.timestamp > self.lastCreditDepositsValueRehydration;
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

    /// @notice Deposits assets to the market as additional credit.
    /// @dev This function assumes the collateral type address is configured in the protocol and has been previously
    /// verified.
    /// @param self The market storage pointer.
    /// @param asset The address of the collateral type being deposited.
    /// @param amountX18 The amount of assets to deposit in the market in 18 decimals.
    function depositCredit(Data storage self, address asset, UD60x18 amountX18) internal {
        AssetToAmountMap.update(self.creditDeposits, asset, amountX18, true);
    }

    /// @notice Deposits assets to the market as additional received fees.
    /// @dev This function assumes the collateral type address is configured in the protocol and has been previously
    /// verified.
    /// @param self The market storage pointer.
    /// @param asset The address of the collateral type being deposited..
    /// @param amountX18 The amount of assets to deposit in the market in 18 decimals.
    function depositFee(Data storage self, address asset, UD60x18 amountX18) internal {
        AssetToAmountMap.update(self.receivedFees, asset, amountX18, true);
    }

    /// @notice Distributes the market's unrealized and realized debt to the connected vaults.
    /// @dev `Market::accumulateVaultDebtAndReward` must be called after this function to update the vault's owned
    /// unrealized and realized credit or debt.
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
        // cache the total vault's shares as SD59x18
        SD59x18 totalVaultSharesX18 = ud60x18(self.totalDelegatedCreditUsd).intoSD59x18();

        // if there is zero delegated credit and we're trying to distribute debt to vaults, we should revert and the
        // market is considered to be in a panic state
        if (totalVaultSharesX18.isZero()) {
            revert Errors.NoDelegatedCredit(self.id);
        }

        // update storage values
        self.realizedDebtUsdPerVaultShare = newRealizedDebtUsdX18.div(totalVaultSharesX18).intoInt256().toInt128();
        self.unrealizedDebtUsdPerVaultShare = newUnrealizedDebtUsdX18.div(totalVaultSharesX18).intoInt256().toInt128();
    }

    /// @notice Updates the amount of usdc available to be distributed to vaults delegating credit to this market.
    /// @dev This function must be called whenever a credit deposit asset is fully swapped for usdc.
    /// @param self The market storage pointer.
    /// @param settledAsset The credit deposit asset that has just been settled for usdc.
    /// @param usdcCreditPerVaultShareX18 The net amount of usdc bought from onchain markets as UD60x18.
    function settleCreditDeposit(
        Data storage self,
        address settledAsset,
        UD60x18 usdcCreditPerVaultShareX18
    )
        internal
    {
        // removes the credit deposit asset that has just been settled for usdc
        self.creditDeposits.remove(settledAsset);

        // add the usdc acquired to the accumulated usdc credit variable
        self.usdcCreditPerVaultShare =
            ud60x18(self.usdcCreditPerVaultShare).add(usdcCreditPerVaultShareX18).intoUint128();
    }

    /// @notice Accumulates a vault's share of the market's unrealized and realized debt since the last distribution,
    /// and calculates the vault's debt changes in USD.
    /// @param self The market storage pointer.
    /// @param vaultId The vault id to accumulate the debt for.
    /// @param lastVaultDistributedWethRewardPerShareX18 The last distributed WETH reward for the given credit
    /// delegation (by
    /// the vault).
    /// @param lastVaultDistributedUnrealizedDebtUsdPerShareX18 The last distributed unrealized debt in USD for the
    /// given
    /// credit delegation (by the vault).
    /// @param lastVaultDistributedRealizedDebtUsdPerShareX18 The last distributed realized debt in USD for the given
    /// credit
    /// delegation (by the vault).
    function accumulateVaultDebtAndReward(
        Data storage self,
        uint128 vaultId,
        UD60x18 lastVaultDistributedWethRewardPerShareX18,
        SD59x18 lastVaultDistributedUnrealizedDebtUsdPerShareX18,
        SD59x18 lastVaultDistributedRealizedDebtUsdPerShareX18
    )
        internal
        returns (UD60x18 wethRewardChangeX18, SD59x18 unrealizedDebtChangeUsdX18, SD59x18 realizedDebtChangeUsdX18)
    {
        // loads the vaults unrealized debt distribution storage pointer
        Distribution.Data storage vaultsDebtDistribution = self.vaultsDebtDistribution;

        if (!ud60x18(vaultsDebtDistribution.totalShares).isZero()) {
            // uint128 -> bytes32
            bytes32 actorId = bytes32(uint256(vaultId));
            // calculate the given vault's ratio of the total delegated credit => actor shares / distribution total
            // shares => then convert it to SD59x18
            // NOTE: `div` rounds down by default, which would lead to a small loss to vaults in a
            // credit state, but a small gain in a debt state. We assume this behavior to be negligible in the
            // protocol's
            // context since the diff is minimal and there are risk parameters ensuring debt settlement happens in a
            // timely manner.
            UD60x18 vaultCreditRatioX18 =
                vaultsDebtDistribution.getActorShares(actorId).div(ud60x18(vaultsDebtDistribution.totalShares));

            // ensure this isn't the first vault debt & reward accumulation, i.e the following value is not zero,
            // before calculating the accumulated weth reward value
            if (!lastVaultDistributedWethRewardPerShareX18.isZero()) {
                wethRewardChangeX18 = vaultCreditRatioX18.mul(
                    lastVaultDistributedWethRewardPerShareX18.sub(ud60x18(self.wethRewardPerVaultShare))
                );
            }

            // cache UD60x18 -> SD59x18 for gas savings
            SD59x18 vaultCreditRatioSd59x18 = vaultCreditRatioX18.intoSD59x18();

            // accumulates the vault's share of the debt since the last distribution, ignoring the return value as
            // it's
            // not needed in this context
            vaultsDebtDistribution.accumulateActor(actorId);
            // multiplies the vault's credit ratio by the change of the market's unrealized debt since the last
            // distribution to determine its share of the unrealized debt change
            unrealizedDebtChangeUsdX18 = vaultCreditRatioSd59x18.mul(
                lastVaultDistributedUnrealizedDebtUsdPerShareX18.sub(sd59x18(self.lastDistributedUnrealizedDebtUsd))
            );
            // multiplies the vault's credit ratio by the change of the market's realized debt since the last
            // distribution to determine its share of the realized debt change
            realizedDebtChangeUsdX18 = vaultCreditRatioSd59x18.mul(
                lastVaultDistributedRealizedDebtUsdPerShareX18.sub(sd59x18(self.lastDistributedRealizedDebtUsd))
            );
        }
    }

    /// @notice Updates the net amount of usd tokens minted and burned by this market.
    /// @param self The market storage pointer.
    /// @param usdTokensIssued The amount of usd tokens being issued in the parent context.
    function updateNetUsdTokenIssuance(Data storage self, SD59x18 usdTokensIssued) internal {
        self.netUsdTokenIssuance = sd59x18(self.netUsdTokenIssuance).add(usdTokensIssued).intoInt256().toInt128();
    }

    /// @notice Rehydrates the credit deposits usd value cache and returns its latest value to the caller.
    /// @param self The market storage pointer.
    /// @return marketRealizedDebtUsdX18 The market's total realized debt in USD.
    function rehydrateCreditDepositsValueCache(Data storage self)
        internal
        returns (SD59x18 creditDepositsValueUsdX18)
    {
        creditDepositsValueUsdX18 = getCreditDepositsValueUsd(self);
        self.creditDepositsValueCacheUsd = creditDepositsValueUsdX18.intoUint128();
        self.lastCreditDepositsValueRehydration = block.timestamp.toUint128();
    }

    /// @notice Updates the market's total credit value delegated by its connected vaults.
    /// @dev This function must be called whenever a vault's credit delegation is updated.
    /// @param self The market storage pointer.
    /// @param creditDeltaUsdX18 The credit value update that is happening in the parent context, to be applied to
    /// the market.
    function updateTotalDelegatedCredit(Data storage self, SD59x18 creditDeltaUsdX18) internal {
        self.totalDelegatedCreditUsd =
            ud60x18(self.totalDelegatedCreditUsd).intoSD59x18().add(creditDeltaUsdX18).intoUD60x18().intoUint128();
    }

    /// @notice Adds the received weth rewards to the stored values of pending protocol weth rewards and vaults' total
    /// weth reward.
    /// @dev For vaults we store the value of all time weth rewards, as the received weth value needs to be further
    /// distributed properly to the `vaultsDebtDistribution`, while the pending protocol weth reward is dynamic as
    /// it's deducted from storage once fees are sent to the recipients.
    /// @dev The given asset is assumed to have been fully consumed in the parent context to acquire the given weth
    /// rewards value, thus, it must be removed from the received market fees map.
    function receiveWethReward(
        Data storage self,
        address asset,
        UD60x18 receivedProtocolWethRewardX18,
        UD60x18 receivedVaultsWethRewardX18
    )
        internal
    {
        // removes the given asset from the received market fees enumerable map as we assume it's been fully swapped
        // to weth
        self.receivedFees.remove(asset);

        // increment the amount o pending weth reward to be distributed to fee recipients
        self.availableProtocolWethReward =
            ud60x18(self.availableProtocolWethReward).add(receivedProtocolWethRewardX18).intoUint128();
        // increment the all time weth reward storage
        self.wethRewardPerVaultShare =
            ud60x18(self.wethRewardPerVaultShare).add(receivedVaultsWethRewardX18).intoUint128();
    }
}
