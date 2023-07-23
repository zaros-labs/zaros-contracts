// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { IPerpsAccountModule } from "../interfaces/IPerpsAccountModule.sol";
import { PerpsAccount } from "../storage/PerpsAccount.sol";

// PRB Math dependencies
import { UD60x18 } from "@prb-math/UD60x18.sol";

contract PerpsAccountModule is IPerpsAccountModule {
    function getPerpsAccountAvailableMargin(address account, address collateralType) external view returns (UD60x18) { }

    function getTotalAvailableMargin(address account) external view returns (UD60x18) { }

    function depositMargin(address collateralType, uint256 amount) external { }

    function withdrawMargin(address collateralType, uint256 amount) external { }

    function addIsolatedMarginToPosition(address account, UD60x18 amount) external { }
}
