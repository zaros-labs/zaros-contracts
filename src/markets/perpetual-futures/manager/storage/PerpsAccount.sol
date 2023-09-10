// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Open Zeppelin dependencies
import { EnumerableMap } from "@openzeppelin/utils/structs/EnumerableMap.sol";
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

library PerpsAccount {
    using EnumerableMap for EnumerableMap.AddressToUintMap;
    using EnumerableSet for EnumerableSet.UintSet;

    /// @dev Constant base domain used to access a given PerpsAccount's storage slot
    string internal constant PERPS_ACCOUNT_DOMAIN = "fi.zaros.markets.PerpsAccount";

    error Zaros_PerpsAccount_PermissionDenied(uint256 accountId, address sender);

    struct Data {
        uint256 id;
        address owner;
        EnumerableMap.AddressToUintMap activeMarginCollateral;
        EnumerableSet.UintSet activeMarketsIds;
    }

    function load(uint256 accountId) internal pure returns (Data storage perpsAccount) {
        bytes32 slot = keccak256(abi.encode(PERPS_ACCOUNT_DOMAIN, accountId));
        assembly {
            perpsAccount.slot := slot
        }
    }

    function loadAccountAndValidatePermission(uint256 accountId) internal view returns (Data storage perpsAccount) {
        perpsAccount = load(accountId);
        verifyCaller(perpsAccount);
    }

    function getMarginCollateral(Data storage perpsAccount, address collateralType) internal view returns (UD60x18) {
        return ud60x18(perpsAccount.activeMarginCollateral.get(collateralType));
    }

    function create(uint256 accountId, address owner) internal returns (Data storage perpsAccount) {
        perpsAccount = load(accountId);
        perpsAccount.id = accountId;
        perpsAccount.owner = owner;
    }

    function increaseMarginCollateral(Data storage perpsAccount, address collateralType, UD60x18 amount) internal {
        EnumerableMap.AddressToUintMap storage activeMarginCollateral = perpsAccount.activeMarginCollateral;
        uint256 newMarginCollateral = ud60x18(activeMarginCollateral.get(collateralType)).add(amount).intoUint256();

        activeMarginCollateral.set(collateralType, newMarginCollateral);
    }

    function decreaseMarginCollateral(Data storage perpsAccount, address collateralType, UD60x18 amount) internal {
        EnumerableMap.AddressToUintMap storage activeMarginCollateral = perpsAccount.activeMarginCollateral;
        UD60x18 newMarginCollateral = ud60x18(activeMarginCollateral.get(collateralType)).sub(amount);

        if (newMarginCollateral.isZero()) {
            activeMarginCollateral.remove(collateralType);
        } else {
            activeMarginCollateral.set(collateralType, newMarginCollateral.intoUint256());
        }
    }

    function updateAccountMarketState(Data storage self, uint256 marketId, bool isActive) internal {
        if (isActive) {
            self.activeMarketsIds.add(marketId);
        } else {
            self.activeMarketsIds.remove(marketId);
        }
    }

    function verifyCaller(Data storage self) internal view {
        if (self.owner != msg.sender) {
            revert Zaros_PerpsAccount_PermissionDenied(self.id, msg.sender);
        }
    }
}
