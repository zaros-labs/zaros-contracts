// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Open Zeppelin dependencies
import { EnumerableMap } from "@openzeppelin/utils/structs/EnumerableMap.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

library PerpsAccount {
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    string internal constant PERPS_ACCOUNT_DOMAIN = "fi.zaros.markets.PerpsAccount";

    struct Data {
        uint256 id;
        EnumerableMap.AddressToUintMap availableMargin;
    }

    /// @dev TODO: use account id / nft id instead of address
    function load(uint256 id) internal pure returns (Data storage perpsAccount) {
        bytes32 slot = keccak256(abi.encode(PERPS_ACCOUNT_DOMAIN, id));
        assembly {
            perpsAccount.slot := slot
        }
    }

    function increaseAvailableMargin(Data storage perpsAccount, address collateralType, UD60x18 amount) internal {
        EnumerableMap.AddressToUintMap storage availableMargin = perpsAccount.availableMargin;
        uint256 newAvailableMargin = ud60x18(availableMargin.get(collateralType)).add(amount).intoUint256();

        availableMargin.set(collateralType, newAvailableMargin);
    }

    function decreaseAvailableMargin(Data storage perpsAccount, address collateralType, UD60x18 amount) internal {
        EnumerableMap.AddressToUintMap storage availableMargin = perpsAccount.availableMargin;
        uint256 newAvailableMargin = ud60x18(availableMargin.get(collateralType)).sub(amount).intoUint256();

        if (newAvailableMargin == 0) {
            availableMargin.remove(collateralType);
        } else {
            availableMargin.set(collateralType, newAvailableMargin);
        }
    }
}
