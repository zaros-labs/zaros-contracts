// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { Order } from "../../market/storage/Order.sol";

// PRB Math dependencies
import { UD60x18 } from "@prb-math/UD60x18.sol";

interface IPerpsAccountModule {
    error Zaros_PerpsAccountModule_InvalidCollateralType(address collateralType);
    error Zaros_PerpsAccountModule_InvalidPerpsMarket(address perpsMarket);

    event LogDepositMargin(address indexed sender, address indexed collateralType, uint256 amount);
    event LogWithdrawMargin(address indexed sender, address indexed collateralType, uint256 amount);

    function getPerpsAccountAvailableMargin(address account, address collateralType) external view returns (UD60x18);

    function getTotalAvailableMargin(address account) external view returns (UD60x18);

    function depositMargin(address collateralType, uint256 amount) external;

    function withdrawMargin(address collateralType, uint256 amount) external;

    function addIsolatedMarginToPosition(
        address account,
        address collateralType,
        UD60x18 amount,
        UD60x18 fee
    )
        external;

    function removeIsolatedMarginFromPosition(address account, address collateralType, UD60x18 amount) external;

    function depositMarginAndSettleOrder(address perpsMarket, Order.Data calldata order) external;

    function settleOrderAndWithdrawMargin(address perpsMarket, Order.Data calldata order) external;
}
