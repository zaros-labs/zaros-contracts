//SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

// Zaros dependencies
import { Constants } from "../../utils/Constants.sol";
import { CollateralConfig } from "./CollateralConfig.sol";
import { Distribution } from "./Distribution.sol";
import { Market } from "./Market.sol";
import { MarketConfiguration } from "./MarketConfiguration.sol";
import { Vault } from "./Vault.sol";

// Open Zeppelin dependencies
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

// PRB Math dependencies
import { UD60x18, ud60x18, ZERO as UD_ZERO, UNIT as UD_UNIT, MAX_UD60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18, ZERO as SD_ZERO } from "@prb-math/SD59x18.sol";

library MarketManager {
    using CollateralConfig for CollateralConfig.Data;
    using Distribution for Distribution.Data;
    using Market for Market.Data;
    using SafeCast for int256;
    using Vault for Vault.Data;

    error Zaros_MarketManager_MinDelegationTimeoutPending(uint32 timeRemaining);

    bytes32 private constant MARKET_MANAGER_SLOT = keccak256(abi.encode("fi.zaros.core.MarketManager"));

    struct Data {
        uint128 minLiquidityRatio;
        uint128 totalMarketsWeight;
        Distribution.Data vaultsDebtDistribution;
        int128 totalVaultDebts;
        address usdToken;
        MarketConfiguration.Data[] marketConfigurations;
        mapping(address collateralType => Vault.Data) vaults;
    }

    function load() internal pure returns (Data storage marketManager) {
        bytes32 s = MARKET_MANAGER_SLOT;
        assembly {
            marketManager.slot := s
        }
    }

    function distributeDebtToVaults(Data storage self, address optionalCollateralType) internal {
        SD59x18 cumulativePendingDebt = SD_ZERO;
        for (uint256 i = 0; i < self.marketConfigurations.length; i++) {
            Market.Data storage market = Market.load(self.marketConfigurations[i].marketAddress);
            cumulativePendingDebt = cumulativePendingDebt.add(sd59x18(market.pendingDebt));
        }

        self.totalVaultDebts = sd59x18(self.totalVaultDebts).add(cumulativePendingDebt).intoInt256().toInt128();
        self.vaultsDebtDistribution.distributeValue(cumulativePendingDebt);

        if (optionalCollateralType != address(0)) {
            bytes32 actorId = bytes32(uint256(uint160(optionalCollateralType)));
            self.vaults[optionalCollateralType].distributeDebtToAccounts(
                self.vaultsDebtDistribution.accumulateActor(actorId)
            );
        }
    }

    function getSystemMaxValuePerShare(
        address marketAddress,
        UD60x18 minLiquidityRatio,
        SD59x18 debtPerShare
    )
        internal
        view
        returns (SD59x18)
    {
        Market.Data storage market = Market.load(marketAddress);
        SD59x18 valuePerShare = market.getDebtPerCredit();
        UD60x18 margin = minLiquidityRatio.isZero() ? UD_UNIT : UD_UNIT.div(minLiquidityRatio);

        return valuePerShare.add(margin.intoSD59x18()).sub(debtPerShare);
    }

    function recalculateVaultCollateral(
        Data storage self,
        address collateralType
    )
        internal
        returns (UD60x18 collateralPrice)
    {
        collateralPrice = CollateralConfig.load(collateralType).getCollateralPrice();
        UD60x18 totalCollateralValue = self.vaults[collateralType].currentCreditCapacity(collateralPrice);

        self.vaultsDebtDistribution.setActorShares(bytes32(uint256(uint160(collateralType))), totalCollateralValue);

        syncMarkets(self);
    }

    function updateAccountDebt(
        Data storage self,
        address collateralType,
        uint128 accountId
    )
        internal
        returns (SD59x18 debt)
    {
        distributeDebtToVaults(self, collateralType);
        return self.vaults[collateralType].consolidateAccountDebt(accountId);
    }

    function resetVault(Data storage self, address collateralType) internal {
        self.vaults[collateralType].reset();

        recalculateVaultCollateral(self, collateralType);
    }

    function syncMarkets(Data storage self) internal {
        UD60x18 totalMarketsWeight = ud60x18(self.totalMarketsWeight);
        if (totalMarketsWeight.isZero()) {
            return;
        }

        UD60x18 totalVaultsCreditCapacity = ud60x18(self.vaultsDebtDistribution.totalShares);
        for (uint256 i = 0; i < self.marketConfigurations.length; i++) {
            MarketConfiguration.Data storage marketConfiguration = self.marketConfigurations[i];
            UD60x18 marketWeight = ud60x18(marketConfiguration.weight);
            UD60x18 marketCreditCapacity = totalVaultsCreditCapacity.mul(marketWeight).div(totalMarketsWeight);

            Market.Data storage market = Market.load(marketConfiguration.marketAddress);
            market.distributeDebt();
            market.creditCapacity = marketCreditCapacity.intoUint128();
        }
    }

    /**
     * @dev Calculates the collateralization ratio of the vault that tracks the given collateral type.
     *
     * The c-ratio is the vault's share of the total debt of the pool, divided by the collateral it delegates to
     * the
     * pool.
     *
     * Note: This is not a view function. It updates the debt distribution chain before performing any
     * calculations.
     */
    function currentVaultCollateralRatio(Data storage self, address collateralType) internal returns (UD60x18) {
        SD59x18 vaultDebt = currentVaultDebt(self, collateralType);
        (, UD60x18 collateralValue) = currentVaultCollateral(self, collateralType);

        return vaultDebt.gt(SD_ZERO) ? collateralValue.div(vaultDebt.intoUD60x18()) : UD_ZERO;
    }

    function findMarketWithCapacityLocked(Data storage self)
        internal
        view
        returns (Market.Data storage lockedMarket)
    {
        for (uint256 i = 0; i < self.marketConfigurations.length; i++) {
            Market.Data storage market = Market.load(self.marketConfigurations[i].marketAddress);

            if (market.isCapacityLocked()) {
                return market;
            }
        }

        // Market zero = null market.
        return Market.load(address(0));
    }

    function getRequiredMinDelegationTime(Data storage self)
        internal
        view
        returns (uint32 requiredMinDelegateTime)
    {
        for (uint256 i = 0; i < self.marketConfigurations.length; i++) {
            uint32 marketMinDelegateTime = Market.load(self.marketConfigurations[i].marketAddress).minDelegateTime;

            if (marketMinDelegateTime > requiredMinDelegateTime) {
                requiredMinDelegateTime = marketMinDelegateTime;
            }
        }

        return Constants.MAX_MIN_DELEGATE_TIME < requiredMinDelegateTime
            ? Constants.MAX_MIN_DELEGATE_TIME
            : requiredMinDelegateTime;
    }

    function currentVaultDebt(Data storage self, address collateralType) internal returns (SD59x18) {
        recalculateVaultCollateral(self, collateralType);

        return self.vaults[collateralType].currentDebt();
    }

    function currentVaultCollateral(
        Data storage self,
        address collateralType
    )
        internal
        view
        returns (UD60x18 collateralAmount, UD60x18 collateralValue)
    {
        UD60x18 collateralPrice = CollateralConfig.load(collateralType).getCollateralPrice();

        collateralAmount = self.vaults[collateralType].currentCollateral();
        collateralValue = collateralPrice.mul(collateralAmount);
    }

    function currentAccountCollateral(
        Data storage self,
        address collateralType,
        uint128 accountId
    )
        internal
        view
        returns (UD60x18 collateralAmount, UD60x18 collateralValue)
    {
        UD60x18 collateralPrice = CollateralConfig.load(collateralType).getCollateralPrice();

        collateralAmount = self.vaults[collateralType].currentAccountCollateral(accountId);
        collateralValue = collateralPrice.mul(collateralAmount);
    }

    function currentAccountCollateralRatio(
        Data storage self,
        address collateralType,
        uint128 accountId
    )
        internal
        returns (UD60x18)
    {
        SD59x18 positionDebt = updateAccountDebt(self, collateralType, accountId);
        if (positionDebt.lte(SD_ZERO)) {
            return MAX_UD60x18;
        }

        (, UD60x18 positionCollateralValue) = currentAccountCollateral(self, collateralType, accountId);

        return positionCollateralValue.div(positionDebt.intoUD60x18());
    }

    function requireMinDelegationTimeElapsed(Data storage self, uint64 lastDelegationTime) internal view {
        uint32 requiredMinDelegationTime = getRequiredMinDelegationTime(self);
        if (block.timestamp < lastDelegationTime + requiredMinDelegationTime) {
            revert Zaros_MarketManager_MinDelegationTimeoutPending(
                uint32(lastDelegationTime + requiredMinDelegationTime - block.timestamp)
            );
        }
    }
}
