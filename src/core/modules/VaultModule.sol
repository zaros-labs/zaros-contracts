//SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

// Zaros dependencies
import { IVaultModule } from "../interfaces/IVaultModule.sol";
import { Account } from "../storage/Account.sol";
import { AccountRBAC } from "../storage/AccountRBAC.sol";
import { Collateral } from "../storage/Collateral.sol";
import { CollateralConfig } from "../storage/CollateralConfig.sol";
import { Vault } from "../storage/Vault.sol";
import { VaultEpoch } from "../storage/VaultEpoch.sol";
import { FeatureFlag } from "../../utils/storage/FeatureFlag.sol";

// Open Zeppelin dependencies
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";

// PRB Math dependencies
import { UD60x18, uUNIT, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18 } from "@prb-math/SD59x18.sol";

/**
 * @title Allows accounts to delegate collateral to a pool.
 * @dev See IVaultModule.
 */
contract VaultModule is IVaultModule {
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using EnumerableSet for EnumerableSet.AddressSet;
    using Vault for Vault.Data;
    using VaultEpoch for VaultEpoch.Data;
    using Collateral for Collateral.Data;
    using CollateralConfig for CollateralConfig.Data;
    using AccountRBAC for AccountRBAC.Data;
    using Distribution for Distribution.Data;
    using CollateralConfiguration for CollateralConfiguration.Data;
    using ScalableMapping for ScalableMapping.Data;

    bytes32 private constant _DELEGATE_FEATURE_FLAG = "delegateCollateral";

    /**
     * @inheritdoc IVaultModule
     */
    function getPositionCollateralRatio(
        uint128 accountId,
        uint128 poolId,
        address collateralType
    )
        external
        override
        returns (uint256)
    {
        return Pool.load(poolId).currentAccountCollateralRatio(collateralType, accountId);
    }

    /**
     * @inheritdoc IVaultModule
     */
    function getVaultCollateralRatio(uint128 poolId, address collateralType) external override returns (uint256) {
        return Pool.load(poolId).currentVaultCollateralRatio(collateralType);
    }

    /**
     * @inheritdoc IVaultModule
     */
    function getPositionCollateral(
        uint128 accountId,
        uint128 poolId,
        address collateralType
    )
        external
        view
        override
        returns (uint256 amount, uint256 value)
    {
        (amount, value) = Pool.load(poolId).currentAccountCollateral(collateralType, accountId);
    }

    /**
     * @inheritdoc IVaultModule
     */
    function getPosition(
        uint128 accountId,
        uint128 poolId,
        address collateralType
    )
        external
        override
        returns (uint256 collateralAmount, uint256 collateralValue, int256 debt, uint256 collateralizationRatio)
    {
        Pool.Data storage pool = Pool.load(poolId);

        debt = pool.updateAccountDebt(collateralType, accountId);
        (collateralAmount, collateralValue) = pool.currentAccountCollateral(collateralType, accountId);
        collateralizationRatio = pool.currentAccountCollateralRatio(collateralType, accountId);
    }

    /**
     * @inheritdoc IVaultModule
     */
    function getPositionDebt(
        uint128 accountId,
        uint128 poolId,
        address collateralType
    )
        external
        override
        returns (int256)
    {
        return Pool.load(poolId).updateAccountDebt(collateralType, accountId);
    }

    /**
     * @inheritdoc IVaultModule
     */
    function getVaultCollateral(
        uint128 poolId,
        address collateralType
    )
        public
        view
        override
        returns (uint256 amount, uint256 value)
    {
        return Pool.load(poolId).currentVaultCollateral(collateralType);
    }

    /**
     * @inheritdoc IVaultModule
     */
    function getVaultDebt(uint128 poolId, address collateralType) public override returns (int256) {
        return Pool.load(poolId).currentVaultDebt(collateralType);
    }

    /**
     * @inheritdoc IVaultModule
     */
    function delegateCollateral(
        uint128 accountId,
        uint128 poolId,
        address collateralType,
        UD60x18 newCollateralAmount,
        uint256 leverage
    )
        external
        override
    {
        FeatureFlag.ensureAccessToFeature(_DELEGATE_FEATURE_FLAG);
        Account.loadAccountAndValidatePermission(accountId, AccountRBAC._DELEGATE_PERMISSION);

        if (newCollateralAmount.gt(ud60x18(0))) {
            CollateralConfiguration.requireSufficientDelegation(collateralType, newCollateralAmount);
        }

        // System only supports leverage of 1.0 for now.
        if (leverage != uUNIT) revert Zaros_VaultModule_InvalidLeverage(leverage);

        Vault.Data storage vault = Pool.loadExisting(poolId).vaults[collateralType];
        vault.updateRewards(accountId, poolId, collateralType);
        uint256 currentCollateralAmount = vault.currentAccountCollateral(accountId);

        if (newCollateralAmount.eq(currentCollateralAmount)) {
            revert Zaros_VaultModule_InvalidCollateralAmount();
        } else if (newCollateralAmount.gt(currentCollateralAmount)) {
            CollateralConfiguration.collateralEnabled(collateralType);
            Account.requireSufficientCollateral(
                accountId, collateralType, newCollateralAmount.sub(currentCollateralAmount)
            );
        } else {
            Pool.loadExisting(poolId).requireMinDelegationTimeElapsed(
                vault.currentEpoch().lastDelegationTime[accountId]
            );
        }
        uint256 collateralPrice =
            _updatePosition(accountId, poolId, collateralType, newCollateralAmount, currentCollateralAmount, leverage);
        _updateAccountCollateralPools(accountId, poolId, collateralType, newCollateralAmount.gt(ud60x18(0)));

        if (newCollateralAmount.lt(currentCollateralAmount)) {
            SD59x18 debt = sd59x18(vault.currentEpoch().consolidatedDebtAmounts[accountId]);
            CollateralConfiguration.load(collateralType).verifyIssuanceRatio(
                debt.lt(sd59x18(0)) ? ud60x18(0) : ud60x18(debt), newCollateralAmount.mul(collateralPrice)
            );
            _verifyNotCapacityLocked(poolId);
        }

        vault.currentEpoch().lastDelegationTime[accountId] = uint64(block.timestamp);

        emit LogDelegateCollateral(
            accountId, poolId, collateralType, newCollateralAmount.intoUint256(), leverage, msg.sender
        );
    }

    /**
     * @dev Updates the given account's position regarding the given pool and collateral type,
     * with the new amount of delegated collateral.
     *
     * The update will be reflected in the registered delegated collateral amount,
     * but it will also trigger updates to the entire debt distribution chain.
     */
    function _updatePosition(
        uint128 accountId,
        uint128 poolId,
        address collateralType,
        UD60x18 newCollateralAmount,
        UD60x18 oldCollateralAmount,
        uint256 leverage
    )
        internal
        returns (uint256 collateralPrice)
    {
        Pool.Data storage pool = Pool.load(poolId);

        // Trigger an update in the debt distribution chain to make sure that
        // the user's debt is up to date.
        pool.updateAccountDebt(collateralType, accountId);

        // Get the collateral entry for the given account and collateral type.
        Collateral.Data storage collateral = Account.load(accountId).collaterals[collateralType];

        // Adjust collateral depending on increase/decrease of amount.
        if (newCollateralAmount.gt(oldCollateralAmount)) {
            collateral.decreaseAvailableCollateral(newCollateralAmount.sub(oldCollateralAmount));
        } else {
            collateral.increaseAvailableCollateral(oldCollateralAmount.sub(newCollateralAmount));
        }

        // If the collateral amount is not negative, make sure that the pool exists
        // in the collateral entry's pool array. Otherwise remove it.
        _updateAccountCollateralPools(accountId, poolId, collateralType, newCollateralAmount.gt(ud60x18(0)));

        // Update the account's position in the vault data structure.
        pool.vaults[collateralType].currentEpoch().updateAccountPosition(accountId, newCollateralAmount, leverage);

        // Trigger another update in the debt distribution chain,
        // and surface the latest price for the given collateral type (which is retrieved in the update).
        collateralPrice = pool.recalculateVaultCollateral(collateralType);
    }

    function _verifyNotCapacityLocked(uint128 poolId) internal view {
        Pool.Data storage pool = Pool.load(poolId);

        Market.Data storage market = pool.findMarketWithCapacityLocked();

        if (market.id > 0) {
            revert Zaros_VaultModule_CapacityLocked(market.id);
        }
    }

    /**
     * @dev Registers the pool in the given account's collaterals array.
     */
    function _updateAccountCollateralPools(
        uint128 accountId,
        uint128 poolId,
        address collateralType,
        bool added
    )
        internal
    {
        Collateral.Data storage depositedCollateral = Account.load(accountId).collaterals[collateralType];

        bool containsPool = depositedCollateral.pools.contains(poolId);
        if (added && !containsPool) {
            depositedCollateral.pools.add(poolId);
        } else if (!added && containsPool) {
            depositedCollateral.pools.remove(poolId);
        }
    }
}
