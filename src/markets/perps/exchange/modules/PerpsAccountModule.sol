// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { IAccountNFT } from "@zaros/account-nft/interfaces/IAccountNFT.sol";
import { ParameterError } from "@zaros/utils/Errors.sol";
import { IPerpsMarket } from "../../engine/interfaces/IPerpsMarket.sol";
import { Order } from "../../engine/storage/Order.sol";
import { OrderFees } from "../../engine/storage/OrderFees.sol";
import { IPerpsAccountModule } from "../interfaces/IPerpsAccountModule.sol";
import { PerpsAccount } from "../storage/PerpsAccount.sol";
import { PerpsConfiguration } from "../storage/PerpsConfiguration.sol";

// Open Zeppelin dependencies
import { EnumerableMap } from "@openzeppelin/utils/structs/EnumerableMap.sol";
import { IERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";
import { SafeERC20 } from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

abstract contract PerpsAccountModule is IPerpsAccountModule {
    using EnumerableMap for EnumerableMap.AddressToUintMap;
    using PerpsAccount for PerpsAccount.Data;
    using SafeERC20 for IERC20;
    using PerpsConfiguration for PerpsConfiguration.Data;

    /// @inheritdoc IPerpsAccountModule
    function getPerpsAccountTokenAddress() public view override returns (address) {
        return PerpsConfiguration.load().perpsPerpsAccountToken;
    }

    /// @inheritdoc IPerpsAccountModule
    function getAccountMarginCollateral(
        uint256 accountId,
        address collateralType
    )
        external
        view
        override
        returns (UD60x18)
    {
        PerpsAccount.Data storage perpsAccount = PerpsAccount.load(accountId);
        UD60x18 marginCollateral = perpsAccount.getMarginCollateral(collateralType);

        return marginCollateral;
    }

    /// @inheritdoc IPerpsAccountModule
    function getTotalAccountMarginCollateralValue(uint256 accountId) external view override returns (UD60x18) { }

    /// @inheritdoc IPerpsAccountModule
    function getAccountMargin(uint256 accountId) external view override returns (UD60x18, UD60x18) { }

    /// @inheritdoc IPerpsAccountModule
    function createPerpsAccount() public override returns (uint256) {
        (uint256 accountId, IAccountNFT perpsPerpsAccountTokenModule) = PerpsConfiguration.onCreateAccount();
        perpsPerpsAccountTokenModule.mint(msg.sender, accountId);

        PerpsAccount.create(accountId, msg.sender);

        emit LogCreatePerpsAccount(accountId, msg.sender);
        return accountId;
    }

    /// @inheritdoc IPerpsAccountModule
    function createPerpsAccountAndMulticall(bytes[] calldata data)
        external
        payable
        override
        returns (bytes[] memory results)
    {
        uint256 accountId = createPerpsAccount();

        results = new bytes[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            bytes memory dataWithAccountId = abi.encodePacked(data[i][0:4], abi.encode(accountId), data[i][4:]);
            (bool success, bytes memory result) = address(this).delegatecall(dataWithAccountId);

            if (!success) {
                uint256 len = result.length;
                assembly {
                    revert(add(result, 0x20), len)
                }
            }

            results[i] = result;
        }
    }

    /// @inheritdoc IPerpsAccountModule
    function depositMargin(uint256 accountId, address collateralType, uint256 amount) external override {
        PerpsConfiguration.Data storage perpsConfiguration = PerpsConfiguration.load();
        _requireCollateralEnabled(collateralType, perpsConfiguration.isCollateralEnabled(collateralType));
        UD60x18 udAmount = ud60x18(amount);
        _requireAmountNotZero(udAmount);
        PerpsAccount.exists(accountId);

        PerpsAccount.Data storage perpsAccount = PerpsAccount.load(accountId);
        perpsAccount.increaseMarginCollateral(collateralType, udAmount);
        IERC20(collateralType).safeTransferFrom(msg.sender, address(this), udAmount.intoUint256());

        emit LogDepositMargin(msg.sender, accountId, collateralType, udAmount.intoUint256());
    }

    /// @inheritdoc IPerpsAccountModule
    function withdrawMargin(uint256 accountId, address collateralType, uint256 amount) external override {
        UD60x18 udAmount = ud60x18(amount);
        _requireAmountNotZero(udAmount);

        PerpsAccount.Data storage perpsAccount = PerpsAccount.loadAccountAndValidatePermission(accountId);
        _checkMarginIsAvailable(perpsAccount, collateralType, udAmount);
        perpsAccount.decreaseMarginCollateral(collateralType, udAmount);
        IERC20(collateralType).safeTransfer(msg.sender, udAmount.intoUint256());

        emit LogWithdrawMargin(msg.sender, accountId, collateralType, udAmount.intoUint256());
    }

    /// @inheritdoc IPerpsAccountModule
    function notifyAccountTransfer(address to, uint128 accountId) external override {
        _onlyPerpsAccountToken();

        PerpsAccount.Data storage perpsAccount = PerpsAccount.load(accountId);
        perpsAccount.owner = to;
    }

    /// @dev Checks if the requested amount of margin collateral is available to be withdrawn.
    /// @dev Iterates over active positions in order to take uPnL and margin requirements into account.
    /// @param perpsAccount The perps account storage pointer.
    /// @param collateralType The margin collateral address.
    /// @param amount The amount of margin collateral to be withdrawn.
    function _checkMarginIsAvailable(
        PerpsAccount.Data storage perpsAccount,
        address collateralType,
        UD60x18 amount
    )
        internal
        view
    { }

    /// @dev Reverts if the caller is not the account owner.
    function _onlyPerpsAccountToken() internal view {
        if (msg.sender != address(getPerpsAccountTokenAddress())) {
            revert Zaros_PerpsAccountModule_OnlyPerpsAccountToken(msg.sender);
        }
    }

    /// @dev Reverts if the amount is zero.
    function _requireAmountNotZero(UD60x18 amount) internal pure {
        if (amount.isZero()) {
            revert ParameterError.Zaros_InvalidParameter("amount", "amount can't be zero");
        }
    }

    /// @dev Reverts if the collateral type is not supported.
    function _requireCollateralEnabled(address collateralType, bool isEnabled) internal pure {
        if (!isEnabled) {
            revert Zaros_PerpsAccountModule_InvalidCollateralType(collateralType);
        }
    }
}
