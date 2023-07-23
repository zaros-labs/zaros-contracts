// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

library PerpsAccount {
    string internal constant PERPS_ACCOUNT_DOMAIN = "fi.zaros.markets.PerpsAccount";

    struct Data {
        mapping(address collateralType => uint256) availableMargin;
    }

    /// @dev TODO: use account id / nft id instead of address
    function load(address account) internal pure returns (Data storage perpsAccount) {
        bytes32 slot = keccak256(abi.encode(PERPS_ACCOUNT_DOMAIN, account));
        assembly {
            perpsAccount.slot := slot
        }
    }

    function increaseAvailableMargin(Data storage perpsAccount, address collateralType, UD60x18 amount) internal {
        perpsAccount.availableMargin[collateralType] =
            ud60x18(perpsAccount.availableMargin[collateralType]).add(amount).intoUint256();
    }

    function decreaseAvailableMargin(Data storage perpsAccount, address collateralType, UD60x18 amount) internal {
        perpsAccount.availableMargin[collateralType] =
            ud60x18(perpsAccount.availableMargin[collateralType]).sub(amount).intoUint256();
    }
}
