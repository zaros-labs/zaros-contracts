// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { MarginCollateral } from "./MarginCollateral.sol";
import { Order } from "./Order.sol";

// Open Zeppelin dependencies
import { EnumerableMap } from "@openzeppelin/utils/structs/EnumerableMap.sol";
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

/// @title The PerpsAccount namespace.
library PerpsAccount {
    using EnumerableMap for EnumerableMap.AddressToUintMap;
    using EnumerableMap for EnumerableMap.UintToUintMap;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using EnumerableSet for EnumerableSet.UintSet;
    using Order for Order.Limit;
    using MarginCollateral for MarginCollateral.Data;

    /// @notice Constant base domain used to access a given PerpsAccount's storage slot.
    string internal constant PERPS_ACCOUNT_DOMAIN = "fi.liquidityEngine.markets.PerpsAccount";

    /// @notice {PerpsAccount} namespace storage structure.
    /// @param id The perps account id.
    /// @param owner The perps account owner.
    /// @param marginCollateralBalance The perps account margin collateral enumerable map.
    /// @param activeMarketsIds The perps account active markets ids enumerable set.
    /// @param activeMarketOrder The perps account's market orders with pending settlement per market.
    /// @dev TODO: implement role based access control.
    struct Data {
        uint128 id;
        uint128 nextLimitOrderId;
        address owner;
        EnumerableMap.AddressToUintMap marginCollateralBalance;
        // EnumerableSet.Bytes32Set activeOrdersPerMarket;
        EnumerableSet.UintSet activeMarketsIds;
        EnumerableSet.AddressSet collateralPriority;
        mapping(uint128 marketId => Order.Market) activeMarketOrder;
        mapping(uint128 marketId => EnumerableMap.UintToUintMap) limitOrdersSlotsPerMarket;
    }

    /// @notice Loads a {PerpsAccount} object.
    /// @param accountId The perps account id.
    /// @return perpsAccount The loaded perps account storage pointer.
    function load(uint256 accountId) internal pure returns (Data storage perpsAccount) {
        bytes32 slot = keccak256(abi.encode(PERPS_ACCOUNT_DOMAIN, accountId));
        assembly {
            perpsAccount.slot := slot
        }
    }

    /// @notice Checks whether the given perps account exists.
    /// @param accountId The perps account id.
    /// @return perpsAccount if the perps account exists, its storage pointer is returned.
    function loadExisting(uint256 accountId) internal view returns (Data storage perpsAccount) {
        perpsAccount = load(accountId);
        if (perpsAccount.owner == address(0)) {
            revert Errors.AccountNotFound(accountId, msg.sender);
        }
    }

    /// @notice TODO: implement
    function canBeLiquidated(Data storage self) internal view returns (bool) {
        return false;
    }

    /// @notice Loads a perps account and checks if the `msg.sender` is authorized.
    /// @param accountId The perps account id.
    /// @return perpsAccount The loaded perps account storage pointer.
    function loadAccountAndValidatePermission(uint256 accountId) internal view returns (Data storage perpsAccount) {
        perpsAccount = load(accountId);
        verifyCaller(perpsAccount);
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
            MarginCollateral.Data storage marginCollateral = MarginCollateral.load(collateralType);
            UD60x18 marginCollateralValue = marginCollateral.getPrice().mul(ud60x18(marginCollateralAmount));

            totalMarginCollateralValue = totalMarginCollateralValue.add(marginCollateralValue);
        }
    }

    /// @notice Verifies if the caller is authorized to perform actions on the given perps account.
    /// @param self The perps account storage pointer.
    function verifyCaller(Data storage self) internal view {
        if (self.owner != msg.sender) {
            revert Errors.PermissionDenied(self.id, msg.sender);
        }
    }

    /// @notice Creates a new perps account.
    /// @param accountId The perps account id.
    /// @param owner The perps account owner.
    /// @return perpsAccount The created perps account storage pointer.
    function create(uint256 accountId, address owner) internal returns (Data storage perpsAccount) {
        perpsAccount = load(accountId);
        perpsAccount.id = accountId;
        perpsAccount.owner = owner;
    }

    function addLimitOrder(Data storage self, uint128 marketId, uint128 price, Order.Payload memory payload) internal {
        uint128 nextLimitOrderId = ++self.nextLimitOrderId;
        uint256 limitOrderSlot = Order.createLimit({ id: nextLimitOrderId, price: price, payload: payload });

        self.limitOrdersSlotsPerMarket[marketId].set(uint256(nextLimitOrderId), limitOrderSlot);
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

    /// @notice Updates the account's active markets ids.
    /// @param self The perps account storage pointer.
    /// @param marketId The perps market id.
    /// @param isActive `true` if the market is active, `false` otherwise.
    function updateActiveMarkets(Data storage self, uint128 marketId, bool isActive) internal {
        if (isActive) {
            self.activeMarketsIds.add(marketId);
        } else {
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
