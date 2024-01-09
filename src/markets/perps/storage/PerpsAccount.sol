// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { MarginCollateralConfiguration } from "./MarginCollateralConfiguration.sol";
import { MarketOrder } from "./MarketOrder.sol";
import { GlobalConfiguration } from "./GlobalConfiguration.sol";

// Open Zeppelin dependencies
import { EnumerableMap } from "@openzeppelin/utils/structs/EnumerableMap.sol";
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, ZERO as SD_ZERO } from "@prb-math/SD59x18.sol";

/// @title The PerpsAccount namespace.
library PerpsAccount {
    using EnumerableMap for EnumerableMap.AddressToUintMap;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;
    using MarginCollateralConfiguration for MarginCollateralConfiguration.Data;
    using GlobalConfiguration for GlobalConfiguration.Data;

    /// @notice Constant base domain used to access a given PerpsAccount's storage slot.
    string internal constant PERPS_ACCOUNT_DOMAIN = "fi.zaros.markets.PerpsAccount";

    /// @notice {PerpsAccount} namespace storage structure.
    /// @param id The perps account id.
    /// @param owner The perps account owner.
    /// @param marginCollateralBalance The perps account margin collateral enumerable map.
    /// @param activeMarketsIds The perps account active markets ids enumerable set.
    /// @dev TODO: implement role based access control.
    struct Data {
        uint128 id;
        address owner;
        EnumerableMap.AddressToUintMap marginCollateralBalance;
        EnumerableSet.UintSet activeMarketsIds;
        EnumerableSet.AddressSet collateralPriority;
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

    function checkIsNotLiquidatable(Data storage self) internal view {
        if (canBeLiquidated(self)) {
            revert Errors.AccountLiquidatable(self.id);
        }
    }

    /// @dev This function must be called when the perps account is going to open a new position. If called in a
    /// context
    /// of an already active market, the check may be misleading.
    function checkCanCreateNewPosition(Data storage self) internal view {
        GlobalConfiguration.Data storage globalConfiguration = GlobalConfiguration.load();

        uint256 maxPositionsPerAccount = globalConfiguration.maxPositionsPerAccount;
        uint256 activePositionsLength = self.activeMarketsIds.length();

        if (activePositionsLength >= maxPositionsPerAccount) {
            revert Errors.MaxPositionsPerAccountReached(self.id, activePositionsLength, maxPositionsPerAccount);
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
    /// @return marginCollateralBalance The margin collateral balance for the given collateral type.
    function getMarginCollateralBalance(Data storage self, address collateralType) internal view returns (UD60x18) {
        (, uint256 marginCollateralBalance) = self.marginCollateralBalance.tryGet(collateralType);

        return ud60x18(marginCollateralBalance);
    }

    /// @notice Returns the notional value of all margin collateral in the account.
    /// @param self The perps account storage pointer.
    /// @return totalMarginCollateralValue The total margin collateral value.
    function getTotalMarginCollateralValue(Data storage self)
        internal
        view
        returns (UD60x18 totalMarginCollateralValue)
    {
        for (uint256 i = 0; i < self.marginCollateralBalance.length(); i++) {
            (address collateralType, uint256 marginCollateralAmount) = self.marginCollateralBalance.at(i);
            MarginCollateralConfiguration.Data storage marginCollateralConfiguration =
                MarginCollateralConfiguration.load(collateralType);
            UD60x18 marginCollateralValue =
                marginCollateralConfiguration.getPrice().mul(ud60x18(marginCollateralAmount));

            totalMarginCollateralValue = totalMarginCollateralValue.add(marginCollateralValue);
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

    /// @notice Increases the margin collateral for the given collateral type.
    /// @dev If there's no collateral priority defined yet, the first collateral type deposited will
    /// be included.
    /// @param self The perps account storage pointer.
    /// @param collateralType The address of the collateral type.
    /// @param amount The amount of margin collateral to be added.
    /// @dev TODO: normalize margin collateral decimals
    function increaseMarginCollateralBalance(Data storage self, address collateralType, UD60x18 amount) internal {
        EnumerableMap.AddressToUintMap storage marginCollateralBalance = self.marginCollateralBalance;
        UD60x18 newMarginCollateralBalance = getMarginCollateralBalance(self, collateralType).add(amount);

        if (self.collateralPriority.length() == 0) {
            self.collateralPriority.add(collateralType);
        }

        marginCollateralBalance.set(collateralType, newMarginCollateralBalance.intoUint256());
    }

    /// @notice Decreases the margin collateral for the given collateral type.
    /// @param self The perps account storage pointer.
    /// @param collateralType The address of the collateral type.
    /// @param amount The amount of margin collateral to be removed.
    /// @dev TODO: denormalize margin collateral decimals
    function decreaseMarginCollateralBalance(Data storage self, address collateralType, UD60x18 amount) internal {
        EnumerableMap.AddressToUintMap storage marginCollateralBalance = self.marginCollateralBalance;
        UD60x18 newMarginCollateralBalance = getMarginCollateralBalance(self, collateralType).sub(amount);

        if (newMarginCollateralBalance.isZero()) {
            marginCollateralBalance.remove(collateralType);
            self.collateralPriority.remove(collateralType);
        } else {
            marginCollateralBalance.set(collateralType, newMarginCollateralBalance.intoUint256());
        }
    }

    function deductAccountMargin(Data storage self, UD60x18 amount) internal {
        for (uint256 i = 0; i < self.collateralPriority.length(); i++) {
            address collateralType = self.collateralPriority.at(i);
            UD60x18 marginCollateralBalance = getMarginCollateralBalance(self, collateralType);
            if (marginCollateralBalance.gte(amount)) {
                decreaseMarginCollateralBalance(self, collateralType, amount);
                break;
            } else {
                decreaseMarginCollateralBalance(self, collateralType, marginCollateralBalance);
                amount = amount.sub(marginCollateralBalance);
            }
        }
    }

    /// @notice Updates the account's active markets ids based on the position's state transition.
    /// @param self The perps account storage pointer.
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

    // /// @notice Updates the account's active orders ids per market.
    // /// @param self The perps account storage pointer.
    // /// @param marketId The perps market id.
    // /// @param orderId the order id.
    // /// @param isActive `true` if the order is being created, `false` otherwise.
    // function updateActiveOrders(Data storage self, uint128 marketId, uint8 orderId, bool isActive) internal {
    //     bytes32 orderAndMarketIds = keccak256(abi.encode(marketId, orderId));
    //     bool success;
    //     if (isActive) {
    //         success = self.activeOrdersPerMarket.add(orderAndMarketIds);
    //     } else {
    //         success = self.activeOrdersPerMarket.remove(orderAndMarketIds);
    //     }
    // }
}
