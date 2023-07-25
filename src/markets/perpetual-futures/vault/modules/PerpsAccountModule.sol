// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { IPerpsAccountModule } from "../interfaces/IPerpsAccountModule.sol";
import { PerpsAccount } from "../storage/PerpsAccount.sol";
import { SystemPerpsMarketsConfiguration } from "../storage/SystemPerpsMarketsConfiguration.sol";

// Open Zeppelin dependencies
import { IERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";
import { SafeERC20 } from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

contract PerpsAccountModule is IPerpsAccountModule {
    using PerpsAccount for PerpsAccount.Data;
    using SafeERC20 for IERC20;
    using SystemPerpsMarketsConfiguration for SystemPerpsMarketsConfiguration.Data;

    function getPerpsAccountAvailableMargin(address account, address collateralType) external view returns (UD60x18) {
        PerpsAccount.Data storage perpsAccount = PerpsAccount.load(account);

        return ud60x18(perpsAccount.availableMargin[collateralType]);
    }

    function getTotalAvailableMargin(address account) external view returns (UD60x18) { }

    function depositMargin(address collateralType, uint256 amount) external {
        SystemPerpsMarketsConfiguration.Data storage systemPerpsMarketsConfiguration =
            SystemPerpsMarketsConfiguration.load();
        _requireCollateralEnabled(collateralType, systemPerpsMarketsConfiguration.isCollateralEnabled(collateralType));
        if (amount == 0) {
            revert();
        }

        PerpsAccount.Data storage perpsAccount = PerpsAccount.load(msg.sender);
        perpsAccount.increaseAvailableMargin(collateralType, ud60x18(amount));
        IERC20(collateralType).safeTransferFrom(msg.sender, address(this), amount);

        emit LogDepositMargin(msg.sender, collateralType, amount);
    }

    function withdrawMargin(address collateralType, uint256 amount) external {
        SystemPerpsMarketsConfiguration.Data storage systemPerpsMarketsConfiguration =
            SystemPerpsMarketsConfiguration.load();
        _requireCollateralEnabled(collateralType, systemPerpsMarketsConfiguration.isCollateralEnabled(collateralType));
        if (amount == 0) {
            revert();
        }

        PerpsAccount.Data storage perpsAccount = PerpsAccount.load(msg.sender);
        perpsAccount.decreaseAvailableMargin(collateralType, ud60x18(amount));
        IERC20(collateralType).safeTransfer(msg.sender, amount);

        emit LogWithdrawMargin(msg.sender, collateralType, amount);
    }

    function addIsolatedMarginToPosition(address account, UD60x18 amount) external { }

    function _requireCollateralEnabled(address collateralType, bool isEnabled) internal pure {
        if (!isEnabled) {
            revert Zaros_PerpsAccountModule_InvalidCollateralType(collateralType);
        }
    }
}
