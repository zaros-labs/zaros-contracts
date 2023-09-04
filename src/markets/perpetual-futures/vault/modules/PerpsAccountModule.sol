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

    function getPerpsAccountAvailableMargin(
        uint256 accountId,
        address collateralType
    )
        external
        view
        returns (UD60x18)
    {
        PerpsAccount.Data storage perpsAccount = PerpsAccount.load(accountId);

        return ud60x18(perpsAccount.availableMargin.get(collateralType));
    }

    function getTotalAvailableMargin(uint256 accountId) external view returns (UD60x18) { }

    function depositMargin(uint256 accountId, address collateralType, uint256 amount) public {
        SystemPerpsMarketsConfiguration.Data storage systemPerpsMarketsConfiguration =
            SystemPerpsMarketsConfiguration.load();
        _requireCollateralEnabled(collateralType, systemPerpsMarketsConfiguration.isCollateralEnabled(collateralType));
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
        _requireCollateralEnabled(collateralType, systemPerpsMarketsConfiguration.isCollateralEnabled(collateralType));
        if (amount == 0) {
            revert();
        }

        PerpsAccount.Data storage perpsAccount = PerpsAccount.load(accountId);
        perpsAccount.decreaseAvailableMargin(collateralType, ud60x18(amount));
        IERC20(collateralType).safeTransfer(msg.sender, amount);

        emit LogWithdrawMargin(msg.sender, collateralType, amount);
    }

    function addIsolatedMarginToPosition(
        uint256 accountId,
        address collateralType,
        UD60x18 amount,
        UD60x18 fee
    )
        external
    {
        SystemPerpsMarketsConfiguration.Data storage systemPerpsMarketsConfiguration =
            SystemPerpsMarketsConfiguration.load();
        _requirePerpsMarketEnabled(systemPerpsMarketsConfiguration.enabledPerpsMarkets[msg.sender]);

        PerpsAccount.Data storage perpsAccount = PerpsAccount.load(accountId);
        perpsAccount.decreaseAvailableMargin(collateralType, amount);

        uint256 amountMinusFee = amount.sub(fee).intoUint256();

        address rewardDistributor = systemPerpsMarketsConfiguration.rewardDistributor;

        IERC20(collateralType).safeTransfer(rewardDistributor, fee.intoUint256());
        IERC20(collateralType).safeTransfer(msg.sender, amountMinusFee);
    }

    function removeIsolatedMarginFromPosition(uint256 accountId, address collateralType, UD60x18 amount) external {
        SystemPerpsMarketsConfiguration.Data storage systemPerpsMarketsConfiguration =
            SystemPerpsMarketsConfiguration.load();
        _requirePerpsMarketEnabled(systemPerpsMarketsConfiguration.enabledPerpsMarkets[msg.sender]);

        PerpsAccount.Data storage perpsAccount = PerpsAccount.load(accountId);
        perpsAccount.increaseAvailableMargin(collateralType, amount);

        /// TODO: add erc20 transfer
    }

    function depositMarginAndSettleOrder(uint256 accountId, address perpsMarket, Order.Data calldata order) external {
        address collateralType = order.collateralType;
        uint256 amount = order.marginAmount;

        depositMargin(accountId, collateralType, amount);
        IPerpsMarket(perpsMarket).settleOrderFromVault(accountId, order);
    }

    function settleOrderAndWithdrawMargin(uint256 accountId, address perpsMarket, Order.Data calldata order) external {
        uint256 previousPositionAmount = IPerpsMarket(perpsMarket).settleOrderFromVault(accountId, order);

        address collateralType = order.collateralType;

        withdrawMargin(accountId, collateralType, previousPositionAmount);
    }

    function _requireCollateralEnabled(address collateralType, bool isEnabled) internal pure {
        if (!isEnabled) {
            revert Zaros_PerpsAccountModule_InvalidCollateralType(collateralType);
        }
    }

    function _requirePerpsMarketEnabled(bool isEnabled) internal view {
        if (!isEnabled) {
            revert Zaros_PerpsAccountModule_InvalidPerpsMarket(msg.sender);
        }
    }
}
