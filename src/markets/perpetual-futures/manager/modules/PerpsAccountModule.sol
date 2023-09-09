// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { IPerpsMarket } from "../../market/interfaces/IPerpsMarket.sol";
import { Order } from "../../market/storage/Order.sol";
import { OrderFees } from "../../market/storage/OrderFees.sol";
import { IPerpsAccountModule } from "../interfaces/IPerpsAccountModule.sol";
import { PerpsAccount } from "../storage/PerpsAccount.sol";
import { SystemPerpsMarketsConfiguration } from "../storage/SystemPerpsMarketsConfiguration.sol";

// Open Zeppelin dependencies
import { EnumerableMap } from "@openzeppelin/utils/structs/EnumerableMap.sol";
import { IERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";
import { SafeERC20 } from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

contract PerpsAccountModule is IPerpsAccountModule {
    using EnumerableMap for EnumerableMap.AddressToUintMap;
    using PerpsAccount for PerpsAccount.Data;
    using SafeERC20 for IERC20;
    using SystemPerpsMarketsConfiguration for SystemPerpsMarketsConfiguration.Data;

    function getAccountMargin(
        uint256 accountId,
        address collateralType
    )
        external
        view
        returns (UD60x18 marginBalance, UD60x18 availableMargin)
    {
        // PerpsAccount.Data storage perpsAccount = PerpsAccount.load(accountId);

        // return ud60x18(perpsAccount.availableMargin.get(collateralType));
    }

    function getTotalAccountMargin(uint256 accountId)
        external
        view
        returns (UD60x18 marginBalance, UD60x18 availableMargin)
    { }

    function createAccount() external returns (uint128) { }

    function createAccountAndMulticall(bytes[] calldata data) external payable returns (bytes[] memory results) { }

    function depositMargin(uint256 accountId, address collateralType, uint256 amount) public {
        SystemPerpsMarketsConfiguration.Data storage systemPerpsMarketsConfiguration =
            SystemPerpsMarketsConfiguration.load();
        // _requireCollateralEnabled(collateralType,
        // systemPerpsMarketsConfiguration.isCollateralEnabled(collateralType));
        if (amount == 0) {
            revert();
        }

        PerpsAccount.Data storage perpsAccount = PerpsAccount.load(accountId);
        perpsAccount.increaseAvailableMargin(collateralType, ud60x18(amount));
        IERC20(collateralType).safeTransferFrom(msg.sender, address(this), amount);

        emit LogDepositMargin(msg.sender, collateralType, amount);
    }

    function withdrawMargin(uint256 accountId, address collateralType, uint256 amount) public {
        SystemPerpsMarketsConfiguration.Data storage systemPerpsMarketsConfiguration =
            SystemPerpsMarketsConfiguration.load();
        // _requireCollateralEnabled(collateralType,
        // systemPerpsMarketsConfiguration.isCollateralEnabled(collateralType));
        if (amount == 0) {
            revert();
        }

        PerpsAccount.Data storage perpsAccount = PerpsAccount.load(accountId);
        perpsAccount.decreaseAvailableMargin(collateralType, ud60x18(amount));
        IERC20(collateralType).safeTransfer(msg.sender, amount);

        emit LogWithdrawMargin(msg.sender, collateralType, amount);
    }

    // function _requireCollateralEnabled(address collateralType, bool isEnabled) internal pure {
    //     if (!isEnabled) {
    //         revert Zaros_PerpsAccountModule_InvalidCollateralType(collateralType);
    //     }
    // }

    // function _requirePerpsMarketEnabled(bool isEnabled) internal view {
    //     if (!isEnabled) {
    //         revert Zaros_PerpsAccountModule_InvalidPerpsMarket(msg.sender);
    //     }
    // }
}
