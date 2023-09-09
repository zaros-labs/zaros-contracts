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
        EnumerableMap.AddressToUintMap marginBalance;
        EnumerableSet.UintSet activeMarketsIds;
    }

    function load(uint256 accountId) internal pure returns (Data storage perpsAccount) {
        bytes32 slot = keccak256(abi.encode(PERPS_ACCOUNT_DOMAIN, accountId));
        assembly {
            perpsAccount.slot := slot
        }
    }

    function loadAccountAndValidatePermission(uint256 accountId) internal returns (Data storage perpsAccount) {
        perpsAccount = load(accountId);
        verifyCaller(perpsAccount);
    }

    function create(uint256 accountId, address owner) internal returns (Data storage perpsAccount) {
        perpsAccount = load(accountId);
        perpsAccount.id = accountId;
        perpsAccount.owner = owner;
    }

    function increaseMarginBalance(Data storage perpsAccount, address collateralType, UD60x18 amount) internal {
        EnumerableMap.AddressToUintMap storage marginBalance = perpsAccount.marginBalance;
        uint256 newMarginBalance = ud60x18(marginBalance.get(collateralType)).add(amount).intoUint256();

        marginBalance.set(collateralType, newMarginBalance);
    }

    function decreaseMarginBalance(Data storage perpsAccount, address collateralType, UD60x18 amount) internal {
        EnumerableMap.AddressToUintMap storage marginBalance = perpsAccount.marginBalance;
        UD60x18 newMarginBalance = ud60x18(marginBalance.get(collateralType)).sub(amount);

        if (newMarginBalance.isZero()) {
            marginBalance.remove(collateralType);
        } else {
            marginBalance.set(collateralType, newMarginBalance.intoUint256());
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
