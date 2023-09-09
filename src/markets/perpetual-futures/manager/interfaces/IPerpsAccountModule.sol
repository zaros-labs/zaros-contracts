// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { Order } from "../../market/storage/Order.sol";

// PRB Math dependencies
import { UD60x18 } from "@prb-math/UD60x18.sol";

interface IPerpsAccountModule {
    error Zaros_PerpsAccountModule_InvalidCollateralType(address collateralType);
    error Zaros_PerpsAccountModule_InvalidPerpsMarket(address perpsMarket);
    error Zaros_PerpsAccountModule_OnlyAccountToken(address sender);

    event LogCreatePerpsAccount(uint256 accountId, address sender);
    event LogDepositMargin(address indexed sender, address indexed collateralType, uint256 amount);
    event LogWithdrawMargin(address indexed sender, address indexed collateralType, uint256 amount);

    function getAccountTokenAddress() external view returns (address);

    function getAccountMargin(
        uint256 accountId,
        address collateralType
    )
        external
        view
        returns (UD60x18 marginBalance, UD60x18 availableMargin);

    function getTotalAccountMargin(uint256 accountId)
        external
        view
        returns (UD60x18 marginBalance, UD60x18 availableMargin);

    function createAccount() external returns (uint128);

    function createAccountAndMulticall(bytes[] calldata data) external payable returns (bytes[] memory results);

    function depositMargin(uint256 accountId, address collateralType, uint256 amount) external;

    function withdrawMargin(uint256 accountId, address collateralType, uint256 amount) external;

    function notifyAccountTransfer(address to, uint128 accountId) external;
}
