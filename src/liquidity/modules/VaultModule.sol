//SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

// Zaros dependencies
import { Constants } from "@zaros/utils/Constants.sol";
import { FeatureFlag } from "@zaros/utils/storage/FeatureFlag.sol";
import { IVaultModule } from "../interfaces/IVaultModule.sol";
import { Account } from "../storage/Account.sol";
import { Collateral } from "../storage/Collateral.sol";
import { CollateralConfig } from "../storage/CollateralConfig.sol";
import { Distribution } from "../storage/Distribution.sol";
import { MarketManager } from "../storage/MarketManager.sol";
import { Market } from "../storage/Market.sol";
import { Vault } from "../storage/Vault.sol";
import { VaultEpoch } from "../storage/VaultEpoch.sol";

// Open Zeppelin dependencies
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";

// PRB Math dependencies
import { UD60x18, UNIT, ud60x18, ZERO as UD_ZERO } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18, ZERO as SD_ZERO } from "@prb-math/SD59x18.sol";

contract VaultModule is IVaultModule {
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using EnumerableSet for EnumerableSet.AddressSet;
    using Vault for Vault.Data;
    using VaultEpoch for VaultEpoch.Data;
    using Collateral for Collateral.Data;
    using CollateralConfig for CollateralConfig.Data;
    using Distribution for Distribution.Data;
    using CollateralConfig for CollateralConfig.Data;
    using MarketManager for MarketManager.Data;

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

    function getVaultCollateralRatio(address collateralType) external override returns (uint256) {
        return MarketManager.load().currentVaultCollateralRatio(collateralType).intoUint256();
    }

    function getPositionCollateral(
        uint128 accountId,
        address collateralType
    )
        external
        view
        override
        returns (uint256 amount, uint256 value)
    {
        (UD60x18 amountUD, UD60x18 valueUD) =
            MarketManager.load().currentAccountCollateral(collateralType, accountId);
        (amount, value) = (amountUD.intoUint256(), valueUD.intoUint256());
    }

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
        collateralizationRatio =
            marketManager.currentAccountCollateralRatio(collateralType, accountId).intoUint256();
    }

    function getPositionDebt(uint128 accountId, address collateralType) external override returns (int256) {
        return MarketManager.load().updateAccountDebt(collateralType, accountId).intoInt256();
    }

    function getVaultCollateral(address collateralType)
        public
        view
        override
        returns (uint256 amount, uint256 value)
    {
        (UD60x18 amountUD, UD60x18 valueUD) = MarketManager.load().currentVaultCollateral(collateralType);
        (amount, value) = (amountUD.intoUint256(), valueUD.intoUint256());
    }

    function getVaultDebt(address collateralType) public override returns (int256) {
        return MarketManager.load().currentVaultDebt(collateralType).intoInt256();
    }

    function delegateCollateral(
        uint128 accountId,
        address collateralType,
        UD60x18 newCollateralAmount
    )
        external
        override
    {
        FeatureFlag.ensureAccessToFeature(Constants.DELEGATE_FEATURE_FLAG);
        Account.loadExistingAccountAndVerifySender(accountId);

        if (newCollateralAmount.gt(UD_ZERO)) {
            CollateralConfig.requireSufficientDelegation(collateralType, newCollateralAmount);
        }

        Vault.Data storage vault = MarketManager.load().vaults[collateralType];
        vault.updateRewards(accountId);

        UD60x18 currentCollateralAmount = vault.currentAccountCollateral(accountId);

        if (newCollateralAmount.eq(currentCollateralAmount)) {
            revert Zaros_VaultModule_InvalidCollateralAmount();
        } else if (newCollateralAmount.gt(currentCollateralAmount)) {
            CollateralConfig.collateralEnabled(collateralType);
            Account.requireSufficientCollateral(
                accountId, collateralType, newCollateralAmount.sub(currentCollateralAmount)
            );
        } else {
            MarketManager.load().requireMinDelegationTimeElapsed(
                vault.currentEpoch().lastDelegationTime[accountId]
            );
        }
        UD60x18 collateralPrice =
            _updatePosition(accountId, collateralType, newCollateralAmount, currentCollateralAmount);

        if (newCollateralAmount.lt(currentCollateralAmount)) {
            SD59x18 debt = sd59x18(vault.currentEpoch().consolidatedDebtAmounts[accountId]);
            CollateralConfig.load(collateralType).verifyIssuanceRatio(
                debt.lt(SD_ZERO) ? UD_ZERO : debt.intoUD60x18(), newCollateralAmount.mul(collateralPrice)
            );
            _verifyNotCapacityLocked();
        }

        vault.currentEpoch().lastDelegationTime[accountId] = uint64(block.timestamp);

        emit LogDelegateCollateral(accountId, collateralType, newCollateralAmount.intoUint256(), msg.sender);
    }

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
        Vault.Data storage vault = MarketManager.load().vaults[collateralType];

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
