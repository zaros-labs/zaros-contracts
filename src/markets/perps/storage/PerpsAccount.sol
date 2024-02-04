// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { MarginCollateralConfiguration } from "./MarginCollateralConfiguration.sol";
import { MarketOrder } from "./MarketOrder.sol";
import { GlobalConfiguration } from "./GlobalConfiguration.sol";
import { PerpMarket } from "./PerpMarket.sol";
import { Position } from "./Position.sol";
import { SettlementConfiguration } from "./SettlementConfiguration.sol";

// Open Zeppelin dependencies
import { EnumerableMap } from "@openzeppelin/utils/structs/EnumerableMap.sol";
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18, ZERO as SD_ZERO } from "@prb-math/SD59x18.sol";

/// @title The PerpsAccount namespace.
library PerpsAccount {
    using EnumerableMap for EnumerableMap.AddressToUintMap;
    using EnumerableSet for *;
    using PerpMarket for PerpMarket.Data;
    using Position for Position.Data;
    using SafeCast for uint256;
    using GlobalConfiguration for GlobalConfiguration.Data;
    using MarginCollateralConfiguration for MarginCollateralConfiguration.Data;
    using SettlementConfiguration for SettlementConfiguration.Data;

    /// @notice Constant base domain used to access a given PerpsAccount's storage slot.
    string internal constant PERPS_ACCOUNT_DOMAIN = "fi.zaros.markets.PerpsAccount";

    /// @notice {PerpsAccount} namespace storage structure.
    /// @param id The perps account id.
    /// @param owner The perps account owner.
    /// @param marginCollateralBalanceX18 The perps account margin collateral enumerable map.
    /// @param activeMarketsIds The perps account active markets ids enumerable set.
    /// @dev TODO: implement role based access control.
    struct Data {
        uint128 id;
        address owner;
        EnumerableMap.AddressToUintMap marginCollateralBalanceX18;
        EnumerableSet.UintSet activeMarketsIds;
    }

    /// @notice Loads a {PerpsAccount} object.
    /// @param accountId The perps account id.
    /// @return perpsAccount The loaded perps account storage pointer.
    function load(uint128 accountId) internal pure returns (Data storage perpsAccount) {
        bytes32 slot = keccak256(abi.encode(PERPS_ACCOUNT_DOMAIN, accountId));
        assembly {
            perpsAccount.slot := slot
        }
    }

    /// @notice Checks whether the given perps account exists.
    /// @param accountId The perps account id.
    /// @return perpsAccount if the perps account exists, its storage pointer is returned.
    function loadExisting(uint128 accountId) internal view returns (Data storage perpsAccount) {
        perpsAccount = load(accountId);
        if (perpsAccount.owner == address(0)) {
            revert Errors.AccountNotFound(accountId, msg.sender);
        }
    }

    /// @notice TODO: implement
    function canBeLiquidated(Data storage self) internal view returns (bool) {
        return false;
    }

    /// @notice Validates if the perps account is under the configured positions limit.
    /// @dev This function must be called when the perps account is going to open a new position. If called in a
    /// context
    /// of an already active market, the check may be misleading.
    function validatePositionsLimit(Data storage self) internal view {
        GlobalConfiguration.Data storage globalConfiguration = GlobalConfiguration.load();

        uint256 maxPositionsPerAccount = globalConfiguration.maxPositionsPerAccount;
        uint256 activePositionsLength = self.activeMarketsIds.length();

        if (activePositionsLength >= maxPositionsPerAccount) {
            revert Errors.MaxPositionsPerAccountReached(self.id, activePositionsLength, maxPositionsPerAccount);
        }
    }

    // TODO: Should we create a Service to handle this?
    /// @notice Validates if the given account will still meet margin requirements after a new settlement.
    /// @dev Reverts if the new account margin state is invalid (requiredMargin >= marginBalance).
    /// @dev Must be called whenever a position is updated.
    /// @param self The perps account storage pointer.
    function validateMarginRequirements(
        Data storage self,
        uint128 settlementMarketId,
        SD59x18 sizeDeltaX18,
        SD59x18 totalFeesUsdX18
    )
        internal
        view
    {
        UD60x18 requiredMarginUsdX18;
        SD59x18 accountTotalUnrealizedPnlUsdX18;

        for (uint256 i = 0; i < self.activeMarketsIds.length(); i++) {
            uint128 marketId = self.activeMarketsIds.at(i).toUint128();

            PerpMarket.Data storage perpMarket = PerpMarket.load(marketId);
            Position.Data storage position = Position.load(self.id, marketId);

            UD60x18 indexPrice = perpMarket.getIndexPrice();
            UD60x18 markPrice = perpMarket.getMarkPrice(SD_ZERO, indexPrice);
            SD59x18 fundingRate = perpMarket.getCurrentFundingRate();
            SD59x18 fundingFeePerUnit = perpMarket.getNextFundingFeePerUnit(fundingRate, markPrice);

            // if we're dealing with the market id being settled, we simulate the new position size to get the new
            // margin requirements.
            UD60x18 notionalValueX18 = marketId != settlementMarketId
                ? position.getNotionalValue(markPrice)
                : sd59x18(position.size).add(sizeDeltaX18).abs().intoUD60x18().mul(markPrice);
            (UD60x18 positionMinInitialMarginUsdX18, UD60x18 positionMaintenanceMarginUsdX18) = Position
                .getMarginRequirements(
                notionalValueX18,
                ud60x18(perpMarket.configuration.minInitialMarginRateX18),
                ud60x18(perpMarket.configuration.maintenanceMarginRateX18)
            );
            SD59x18 positionUnrealizedPnl =
                position.getUnrealizedPnl(markPrice).add(position.getAccruedFunding(fundingFeePerUnit));

            requiredMarginUsdX18 =
                requiredMarginUsdX18.add(positionMinInitialMarginUsdX18).add(positionMaintenanceMarginUsdX18);
            accountTotalUnrealizedPnlUsdX18 = accountTotalUnrealizedPnlUsdX18.add(positionUnrealizedPnl);
        }

        SD59x18 marginBalanceUsdX18 = getMarginBalanceUsd(self, accountTotalUnrealizedPnlUsdX18);

        if (requiredMarginUsdX18.intoSD59x18().add(totalFeesUsdX18).gte(marginBalanceUsdX18)) {
            revert Errors.InsufficientMargin(
                self.id,
                marginBalanceUsdX18.intoInt256(),
                totalFeesUsdX18.intoInt256(),
                requiredMarginUsdX18.intoUint256()
            );
        }
    }

    /// @notice Loads an existing perps account and checks if the `msg.sender` is authorized.
    /// @param accountId The perps account id.
    /// @return perpsAccount The loaded perps account storage pointer.
    function loadExistingAccountAndVerifySender(uint128 accountId)
        internal
        view
        returns (Data storage perpsAccount)
    {
        verifySender(accountId);
        perpsAccount = loadExisting(accountId);
    }

    /// @notice Returns the amount of the given margin collateral type.
    /// @param self The perps account storage pointer.
    /// @param collateralType The address of the collateral type.
    /// @return marginCollateralBalanceX18 The margin collateral balance for the given collateral type.
    function getMarginCollateralBalance(Data storage self, address collateralType) internal view returns (UD60x18) {
        (, uint256 marginCollateralBalanceX18) = self.marginCollateralBalanceX18.tryGet(collateralType);

        return ud60x18(marginCollateralBalanceX18);
    }

    /// @notice Returns the notional value of all margin collateral in the account.
    /// @param self The perps account storage pointer.
    /// @return equityUsdX18 The total margin collateral value.
    function getEquityUsd(
        Data storage self,
        SD59x18 activePositionsUnrealizedPnlUsdX18
    )
        internal
        view
        returns (SD59x18 equityUsdX18)
    {
        for (uint256 i = 0; i < self.marginCollateralBalanceX18.length(); i++) {
            (address collateralType, uint256 balanceX18) = self.marginCollateralBalanceX18.at(i);
            MarginCollateralConfiguration.Data storage marginCollateralConfiguration =
                MarginCollateralConfiguration.load(collateralType);
            UD60x18 balanceUsdX18 = marginCollateralConfiguration.getPrice().mul(ud60x18(balanceX18));

            equityUsdX18 = equityUsdX18.add(balanceUsdX18.intoSD59x18());
        }

        equityUsdX18 = equityUsdX18.add(activePositionsUnrealizedPnlUsdX18);
    }

    function getMarginBalanceUsd(
        Data storage self,
        SD59x18 activePositionsUnrealizedPnlUsdX18
    )
        internal
        view
        returns (SD59x18 marginBalanceUsdX18)
    {
        for (uint256 i = 0; i < self.marginCollateralBalanceX18.length(); i++) {
            (address collateralType, uint256 balanceX18) = self.marginCollateralBalanceX18.at(i);
            MarginCollateralConfiguration.Data storage marginCollateralConfiguration =
                MarginCollateralConfiguration.load(collateralType);
            UD60x18 adjustedBalanceUsdX18 = marginCollateralConfiguration.getPrice().mul(ud60x18(balanceX18)).mul(
                ud60x18(marginCollateralConfiguration.loanToValue)
            );

            marginBalanceUsdX18 = marginBalanceUsdX18.add(adjustedBalanceUsdX18.intoSD59x18());
        }

        marginBalanceUsdX18 = marginBalanceUsdX18.add(activePositionsUnrealizedPnlUsdX18);
    }

    // TODO: Should we create a Service to handle this?
    function getAccountUnrealizedPnlUsd(Data storage self) internal view returns (SD59x18 totalUnrealizedPnlUsdX18) {
        for (uint256 i = 0; i < self.activeMarketsIds.length(); i++) {
            uint128 marketId = self.activeMarketsIds.at(i).toUint128();
            PerpMarket.Data storage perpMarket = PerpMarket.load(marketId);
            Position.Data storage position = Position.load(self.id, marketId);

            UD60x18 indexPrice = perpMarket.getIndexPrice();
            UD60x18 markPrice = perpMarket.getMarkPrice(SD_ZERO, indexPrice);
            SD59x18 unrealizedPnlUsdX18 = position.getUnrealizedPnl(markPrice);

            totalUnrealizedPnlUsdX18 = totalUnrealizedPnlUsdX18.add(unrealizedPnlUsdX18);
        }
    }

    /// @notice Verifies if the `msg.sender` is authorized to perform actions on the given perps account id.
    /// @param accountId The perps account id.
    function verifySender(uint128 accountId) internal view {
        Data storage self = load(accountId);
        if (self.owner != msg.sender) {
            revert Errors.AccountPermissionDenied(accountId, msg.sender);
        }
    }

    function isMarketWithActivePosition(Data storage self, uint128 marketId) internal view returns (bool) {
        return self.activeMarketsIds.contains(marketId);
    }

    /// @notice Creates a new perps account.
    /// @param accountId The perps account id.
    /// @param owner The perps account owner.
    /// @return perpsAccount The created perps account storage pointer.
    function create(uint128 accountId, address owner) internal returns (Data storage perpsAccount) {
        perpsAccount = load(accountId);
        perpsAccount.id = accountId;
        perpsAccount.owner = owner;
    }

    /// @notice Deposits the given collateral type into the perps account.
    /// @param self The perps account storage pointer.
    /// @param collateralType The address of the collateral type.
    /// @param amountX18 The amount of margin collateral to be added.
    function deposit(Data storage self, address collateralType, UD60x18 amountX18) internal {
        EnumerableMap.AddressToUintMap storage marginCollateralBalanceX18 = self.marginCollateralBalanceX18;
        UD60x18 newMarginCollateralBalance = getMarginCollateralBalance(self, collateralType).add(amountX18);

        marginCollateralBalanceX18.set(collateralType, newMarginCollateralBalance.intoUint256());
    }

    /// @notice Withdraws the given collateral type from the perps account.
    /// @param self The perps account storage pointer.
    /// @param collateralType The address of the collateral type.
    /// @param amountX18 The amount of margin collateral to be removed.
    function withdraw(Data storage self, address collateralType, UD60x18 amountX18) internal {
        EnumerableMap.AddressToUintMap storage marginCollateralBalanceX18 = self.marginCollateralBalanceX18;
        UD60x18 newMarginCollateralBalance = getMarginCollateralBalance(self, collateralType).sub(amountX18);

        if (newMarginCollateralBalance.isZero()) {
            marginCollateralBalanceX18.remove(collateralType);
        } else {
            marginCollateralBalanceX18.set(collateralType, newMarginCollateralBalance.intoUint256());
        }
    }

    function deductAccountMargin(Data storage self, UD60x18 amount) internal {
        GlobalConfiguration.Data storage globalConfiguration = GlobalConfiguration.load();

        for (uint256 i = 0; i < globalConfiguration.collateralPriority.length(); i++) {
            address collateralType = globalConfiguration.collateralPriority.at(i);
            UD60x18 marginCollateralBalanceX18 = getMarginCollateralBalance(self, collateralType);
            if (marginCollateralBalanceX18.gte(amount)) {
                withdraw(self, collateralType, amount);
                break;
            } else {
                withdraw(self, collateralType, marginCollateralBalanceX18);
                amount = amount.sub(marginCollateralBalanceX18);
            }
        }
    }

    /// @notice Updates the account's active markets ids based on the position's state transition.
    /// @param self The perps account storage pointer.
    /// @param marketId The perps market id.
    /// @param oldPositionSize The old position size.
    /// @param newPositionSize The new position size.
    function updateActiveMarkets(
        Data storage self,
        uint128 marketId,
        SD59x18 oldPositionSize,
        SD59x18 newPositionSize
    )
        internal
    {
        if (oldPositionSize.eq(SD_ZERO) && newPositionSize.neq(SD_ZERO)) {
            self.activeMarketsIds.add(marketId);
        } else if (oldPositionSize.neq(SD_ZERO) && newPositionSize.eq(SD_ZERO)) {
            self.activeMarketsIds.remove(marketId);
        }
    }
}
