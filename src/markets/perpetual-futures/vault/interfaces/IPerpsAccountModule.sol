// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// PRB Math dependencies
import { UD60x18 } from "@prb-math/UD60x18.sol";

interface IPerpsAccountModule {
    function getPerpsAccountAvailableMargin(address account, address collateralType) external view returns (UD60x18);

    function getTotalAvailableMargin(address account) external view returns (UD60x18);

    function depositMargin(address collateralType, uint256 amount) external;

    function withdrawMargin(address collateralType, uint256 amount) external;

    function addIsolatedMarginToPosition(address account, UD60x18 amount) external;
}
