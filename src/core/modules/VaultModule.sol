//SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

// Zaros dependencies
import { IVaultModule } from "../interfaces/IVaultModule.sol";
import { Account } from "../storage/Account.sol";
import { AccountRBAC } from "../storage/AccountRBAC.sol";
import { Collateral } from "../storage/Collateral.sol";
import { CollateralConfig } from "../storage/CollateralConfig.sol";
import { Distribution } from "../storage/Distribution.sol";
import { MarketManager } from "../storage/MarketManager.sol";
import { Market } from "../storage/Market.sol";
import { Vault } from "../storage/Vault.sol";
import { VaultEpoch } from "../storage/VaultEpoch.sol";
import { FeatureFlag } from "../../utils/storage/FeatureFlag.sol";

// Open Zeppelin dependencies
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";

// PRB Math dependencies
import { UD60x18, UNIT, ud60x18, ZERO as UD_ZERO } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18, ZERO as SD_ZERO } from "@prb-math/SD59x18.sol";

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
    using CollateralConfig for CollateralConfig.Data;
    using MarketManager for MarketManager.Data;

    bytes32 private constant _DELEGATE_FEATURE_FLAG = "delegateCollateral";

    /**
     * @inheritdoc IVaultModule
     */
    function getPositionCollateralRatio(
        uint128 accountId,
        address collateralType
    )
        external
        override
        returns (uint256)
    {
        return MarketManager.load().currentAccountCollateralRatio(collateralType, accountId).intoUint256();
    }

    /**
     * @inheritdoc IVaultModule
     */
    function getVaultCollateralRatio(address collateralType) external override returns (uint256) {
        return MarketManager.load().currentVaultCollateralRatio(collateralType).intoUint256();
    }

    /**
     * @inheritdoc IVaultModule
     */
    function getPositionCollateral(
        uint128 accountId,
        address collateralType
    )
        external
        view
        override
        returns (uint256 amount, uint256 value)
    {
        (UD60x18 amountUD, UD60x18 valueUD) = MarketManager.load().currentAccountCollateral(collateralType, accountId);
        (amount, value) = (amountUD.intoUint256(), valueUD.intoUint256());
    }

    /**
     * @inheritdoc IVaultModule
     */
    function getPosition(
        uint128 accountId,
        address collateralType
    )
        external
        override
        returns (uint256 collateralAmount, uint256 collateralValue, int256 debt, uint256 collateralizationRatio)
    {
        MarketManager.Data storage marketManager = MarketManager.load();

        debt = marketManager.updateAccountDebt(collateralType, accountId).intoInt256();
        (UD60x18 collateralAmountUD, UD60x18 collateralValueUD) =
            marketManager.currentAccountCollateral(collateralType, accountId);
        (collateralAmount, collateralValue) = (collateralAmountUD.intoUint256(), collateralValueUD.intoUint256());
        collateralizationRatio = marketManager.currentAccountCollateralRatio(collateralType, accountId).intoUint256();
    }

    /**
     * @inheritdoc IVaultModule
     */
    function getPositionDebt(uint128 accountId, address collateralType) external override returns (int256) {
        return MarketManager.load().updateAccountDebt(collateralType, accountId).intoInt256();
    }

    /**
     * @inheritdoc IVaultModule
     */
    function getVaultCollateral(address collateralType) public view override returns (uint256 amount, uint256 value) {
        (UD60x18 amountUD, UD60x18 valueUD) = MarketManager.load().currentVaultCollateral(collateralType);
        (amount, value) = (amountUD.intoUint256(), valueUD.intoUint256());
    }

    /**
     * @inheritdoc IVaultModule
     */
    function getVaultDebt(address collateralType) public override returns (int256) {
        return MarketManager.load().currentVaultDebt(collateralType).intoInt256();
    }

    /**
     * @inheritdoc IVaultModule
     */
    function delegateCollateral(
        uint128 accountId,
        address collateralType,
        uint256 newCollateralAmount
    )
        external
        override
    {
        FeatureFlag.ensureAccessToFeature(_DELEGATE_FEATURE_FLAG);
        Account.loadAccountAndValidatePermission(accountId, AccountRBAC._DELEGATE_PERMISSION);
        UD60x18 amount = ud60x18(newCollateralAmount);

        if (amount.gt(UD_ZERO)) {
            CollateralConfig.requireSufficientDelegation(collateralType, amount);
        }

        Vault.Data storage vault = Vault.load(collateralType);
        vault.updateRewards(accountId);
        UD60x18 currentCollateralAmount = vault.currentAccountCollateral(accountId);

        if (amount.eq(currentCollateralAmount)) {
            revert Zaros_VaultModule_InvalidCollateralAmount();
        } else if (amount.gt(currentCollateralAmount)) {
            CollateralConfig.collateralEnabled(collateralType);
            Account.requireSufficientCollateral(accountId, collateralType, amount.sub(currentCollateralAmount));
        } else {
            MarketManager.load().requireMinDelegationTimeElapsed(vault.currentEpoch().lastDelegationTime[accountId]);
        }
        UD60x18 collateralPrice = _updatePosition(accountId, collateralType, amount, currentCollateralAmount);

        if (amount.lt(currentCollateralAmount)) {
            SD59x18 debt = sd59x18(vault.currentEpoch().consolidatedDebtAmounts[accountId]);
            CollateralConfig.load(collateralType).verifyIssuanceRatio(
                debt.lt(SD_ZERO) ? UD_ZERO : debt.intoUD60x18(), amount.mul(collateralPrice)
            );
            _verifyNotCapacityLocked();
        }

        vault.currentEpoch().lastDelegationTime[accountId] = uint64(block.timestamp);

        emit LogDelegateCollateral(accountId, collateralType, amount.intoUint256(), msg.sender);
    }

    /**
     * @dev Updates the given account's position regarding the given collateral type,
     * with the new amount of delegated collateral.
     *
     * The update will be reflected in the registered delegated collateral amount,
     * but it will also trigger updates to the entire debt distribution chain.
     */
    function _updatePosition(
        uint128 accountId,
        address collateralType,
        UD60x18 newCollateralAmount,
        UD60x18 oldCollateralAmount
    )
        internal
        returns (UD60x18 collateralPrice)
    {
        MarketManager.Data storage marketManager = MarketManager.load();
        Vault.Data storage vault = Vault.load(collateralType);

        // Trigger an update in the debt distribution chain to make sure that
        // the user's debt is up to date.
        marketManager.updateAccountDebt(collateralType, accountId);

        // Get the collateral entry for the given account and collateral type.
        Collateral.Data storage collateral = Account.load(accountId).collaterals[collateralType];

        // Adjust collateral depending on increase/decrease of amount.
        if (newCollateralAmount.gt(oldCollateralAmount)) {
            collateral.decreaseAvailableCollateral(newCollateralAmount.sub(oldCollateralAmount));
        } else {
            collateral.increaseAvailableCollateral(oldCollateralAmount.sub(newCollateralAmount));
        }

        // Update the account's position in the vault data structure.
        vault.currentEpoch().updateAccountPosition(accountId, newCollateralAmount);

        // Trigger another update in the debt distribution chain,
        // and surface the latest price for the given collateral type (which is retrieved in the update).
        collateralPrice = marketManager.recalculateVaultCollateral(collateralType);
    }

    function _verifyNotCapacityLocked() internal view {
        MarketManager.Data storage marketManager = MarketManager.load();

        Market.Data storage market = marketManager.findMarketWithCapacityLocked();

        if (market.marketAddress != address(0)) {
            revert Zaros_VaultModule_CapacityLocked(market.marketAddress);
        }
    }
}
