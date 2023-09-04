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

    function getPerpsAccountAvailableMargin(
        uint256 accountId,
        address collateralType
    )
        external
        view
        returns (UD60x18);

    function getTotalAvailableMargin(uint256 accountId) external view returns (UD60x18);

    // function createAccount() external returns (uint256);

    // function createAccountAndMulticall(bytes[] calldata data) external payable returns (bytes[] memory results);

    function depositMargin(uint256 accountId, address collateralType, uint256 amount) external;

    function withdrawMargin(uint256 accountId, address collateralType, uint256 amount) external;

    function addIsolatedMarginToPosition(
        uint256 accountId,
        address collateralType,
        UD60x18 amount,
        UD60x18 fee
    )
        external;

    function removeIsolatedMarginFromPosition(uint256 accountId, address collateralType, UD60x18 amount) external;

    function depositMarginAndSettleOrder(uint256 accountId, address perpsMarket, Order.Data calldata order) external;

    function settleOrderAndWithdrawMargin(uint256 accountId, address perpsMarket, Order.Data calldata order) external;
}
