// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Open Zeppelin dependencies
import { EnumerableMap } from "@openzeppelin/utils/structs/EnumerableMap.sol";
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

/// @title The PerpsAccount namespace.
library PerpsAccount {
    using EnumerableMap for EnumerableMap.AddressToUintMap;
    using EnumerableSet for EnumerableSet.UintSet;

    /// @notice Thrown when the caller is not authorized by the owner of the PerpsAccount.
    error Zaros_PerpsAccount_PermissionDenied(uint256 accountId, address sender);
    /// @notice Thrown when the given `accountId` doesn't exist.
    error Zaros_PerpsAccount_AccountNotFound(uint256 accountId, address sender);

    /// @dev Constant base domain used to access a given PerpsAccount's storage slot.
    string internal constant PERPS_ACCOUNT_DOMAIN = "fi.zaros.markets.PerpsAccount";

    /// @notice {PerpsAccount} namespace storage structure.
    /// @param id The perps account id.
    /// @param owner The perps account owner.
    /// @param marginCollateral The perps account margin collateral enumerable map.
    /// @param activeMarketsIds The perps account active markets ids enumerable set.
    /// @dev TODO: implement role based access control.
    struct Data {
        uint256 id;
        address owner;
        EnumerableMap.AddressToUintMap marginCollateral;
        EnumerableSet.UintSet activeMarketsIds;
    }

    /// @dev Loads a PerpsAccount entity.
    /// @param accountId The perps account id.
    /// @return perpsAccount The loaded perps account storage pointer.
    function load(uint256 accountId) internal pure returns (Data storage perpsAccount) {
        bytes32 slot = keccak256(abi.encode(PERPS_ACCOUNT_DOMAIN, accountId));
        assembly {
            perpsAccount.slot := slot
        }
    }

    /// @dev Checks whether the given perps account exists.
    /// @param accountId The perps account id.
    /// @return perpsAccount if the perps account exists, its storage pointer is returned.
    function exists(uint256 accountId) internal view returns (Data storage perpsAccount) {
        perpsAccount = load(accountId);
        if (perpsAccount.owner == address(0)) {
            revert Zaros_PerpsAccount_AccountNotFound(accountId, msg.sender);
        }
    }

    /// @dev TODO; implement
    function canBeLiquidated(Data storage self) internal view returns (bool) {
        return false;
    }

    /// @dev Loads a perps account and checks if the `msg.sender` is authorized.
    /// @param accountId The perps account id.
    /// @return perpsAccount The loaded perps account storage pointer.
    function loadAccountAndValidatePermission(uint256 accountId) internal view returns (Data storage perpsAccount) {
        perpsAccount = load(accountId);
        verifyCaller(perpsAccount);
    }

    /// @dev Returns the margin collateral for the given collateral type.
    /// @param self The perps account storage pointer.
    /// @param collateralType The address of the collateral type.
    /// @return marginCollateral The amount of margin collateral for the given collateral type.
    function getMarginCollateral(Data storage self, address collateralType) internal view returns (UD60x18) {
        return ud60x18(self.marginCollateral.get(collateralType));
    }

    /// @dev Creates a new perps account.
    /// @param accountId The perps account id.
    /// @param owner The perps account owner.
    /// @return perpsAccount The created perps account storage pointer.
    function create(uint256 accountId, address owner) internal returns (Data storage perpsAccount) {
        perpsAccount = load(accountId);
        perpsAccount.id = accountId;
        perpsAccount.owner = owner;
    }

    /// @dev Increases the margin collateral for the given collateral type.
    /// @param self The perps account storage pointer.
    /// @param collateralType The address of the collateral type.
    /// @param amount The amount of margin collateral to be added.
    /// @dev TODO: normalize margin collateral decimals
    function increaseMarginCollateral(Data storage self, address collateralType, UD60x18 amount) internal {
        EnumerableMap.AddressToUintMap storage marginCollateral = self.marginCollateral;
        (, uint256 currentMarginCollateral) = marginCollateral.tryGet(collateralType);
        uint256 newMarginCollateral = ud60x18(currentMarginCollateral).add(amount).intoUint256();

        marginCollateral.set(collateralType, newMarginCollateral);
    }

    /// @dev Decreases the margin collateral for the given collateral type.
    /// @param self The perps account storage pointer.
    /// @param collateralType The address of the collateral type.
    /// @param amount The amount of margin collateral to be removed.
    /// @dev TODO: denormalize margin collateral decimals
    function decreaseMarginCollateral(Data storage self, address collateralType, UD60x18 amount) internal {
        EnumerableMap.AddressToUintMap storage marginCollateral = self.marginCollateral;
        UD60x18 newMarginCollateral = ud60x18(marginCollateral.get(collateralType)).sub(amount);

        if (newMarginCollateral.isZero()) {
            marginCollateral.remove(collateralType);
        } else {
            marginCollateral.set(collateralType, newMarginCollateral.intoUint256());
        }
    }

    /// @dev Updates the account's active markets ids.
    /// @param self The perps account storage pointer.
    /// @param marketId The perps market id.
    /// @param isActive `true` if the market is active, `false` otherwise.
    function updateAccountMarketState(Data storage self, uint256 marketId, bool isActive) internal {
        if (isActive) {
            self.activeMarketsIds.add(marketId);
        } else {
            self.activeMarketsIds.remove(marketId);
        }
    }

    /// @dev Verifies if the caller is authorized to perform actions on the given perps account.
    /// @param self The perps account storage pointer.
    function verifyCaller(Data storage self) internal view {
        if (self.owner != msg.sender) {
            revert Zaros_PerpsAccount_PermissionDenied(self.id, msg.sender);
        }
    }
}
