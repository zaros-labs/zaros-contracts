// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { Account } from "../storage/Account.sol";
import { ICollateralModule } from "../interfaces/ICollateralModule.sol";
import { Collateral } from "../storage/Collateral.sol";
import { CollateralConfig } from "../storage/CollateralConfig.sol";
import { FeatureFlag } from "../../utils/storage/FeatureFlag.sol";

// Open Zeppelin dependencies
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";
import { Ownable } from "@openzeppelin/access/Ownable.sol";
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";
import { IERC20, SafeERC20 } from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";

// PRB Math dependencies
import { UD60x18 } from "@prb-math/UD60x18.sol";

/**
 * @title Module for managing user collateral.
 * @dev See ICollateralModule.
 */
contract CollateralModule is ICollateralModule, Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;
    using CollateralConfig for CollateralConfig.Data;
    using Account for Account.Data;
    using Collateral for Collateral.Data;
    using SafeCast for uint256;
    using SafeERC20 for IERC20;

    bytes32 private constant _DEPOSIT_FEATURE_FLAG = "deposit";
    bytes32 private constant _WITHDRAW_FEATURE_FLAG = "withdraw";

    function getCollateralConfigs(bool hideDisabled) external view override returns (CollateralConfig.Data[] memory) {
        EnumerableSet.AddressSet storage collateralTypes = CollateralConfig.loadAvailableCollaterals();

        uint256 numCollaterals = collateralTypes.length();
        CollateralConfig.Data[] memory filteredCollaterals = new CollateralConfig.Data[](numCollaterals);

        uint256 collateralsIdx;
        for (uint256 i = 1; i <= numCollaterals; i++) {
            address collateralType = collateralTypes.at(i);

            CollateralConfig.Data storage collateral = CollateralConfig.load(collateralType);

            if (!hideDisabled || collateral.depositingEnabled) {
                filteredCollaterals[collateralsIdx++] = collateral;
            }
        }

        return filteredCollaterals;
    }

    function getCollateralConfig(address collateralType)
        external
        pure
        override
        returns (CollateralConfig.Data memory)
    {
        return CollateralConfig.load(collateralType);
    }

    function getCollateralPrice(address collateralType) external view override returns (uint256) {
        return CollateralConfig.getCollateralPrice(CollateralConfig.load(collateralType)).intoUint256();
    }

    function getAccountCollateral(
        uint128 accountId,
        address collateralType
    )
        external
        view
        override
        returns (UD60x18 totalDeposited, UD60x18 totalAssigned)
    {
        return Account.load(accountId).getCollateralTotals(collateralType);
    }

    function getAccountAvailableCollateral(
        uint128 accountId,
        address collateralType
    )
        public
        view
        override
        returns (uint256)
    {
        return Account.load(accountId).collaterals[collateralType].amountAvailableForDelegation;
    }

    function configureCollateral(CollateralConfig.Data memory collateralConfig) external override onlyOwner {
        // TODO: add input validation
        CollateralConfig.set(collateralConfig);

        emit LogConfigureCollateral(collateralConfig.tokenAddress, collateralConfig);
    }

    /// @dev TODO: add deposit cap check
    function deposit(uint128 accountId, address collateralType, uint256 tokenAmount) external override {
        FeatureFlag.ensureAccessToFeature(_DEPOSIT_FEATURE_FLAG);
        CollateralConfig.collateralEnabled(collateralType);
        Account.exists(accountId);

        Account.Data storage account = Account.load(accountId);

        address depositFrom = msg.sender;
        address self = address(this);
        IERC20(collateralType).safeTransferFrom(depositFrom, self, tokenAmount);

        UD60x18 normalizedTokenAmount = CollateralConfig.load(collateralType).normalizeTokenAmount(tokenAmount);
        account.collaterals[collateralType].increaseAvailableCollateral(normalizedTokenAmount);

        emit LogDeposit(accountId, collateralType, tokenAmount, msg.sender);
    }

    function withdraw(uint128 accountId, address collateralType, uint256 tokenAmount) external override {
        FeatureFlag.ensureAccessToFeature(_WITHDRAW_FEATURE_FLAG);
        // Account.Data storage account = Account.loadAccountAndValidatePermissionAndTimeout(
        //     accountId, Config.readUint(_CONFIG_TIMEOUT_WITHDRAW, 0)
        // );
        Account.Data storage account = Account.loadAccountAndValidatePermission(accountId);

        UD60x18 tokenWad = CollateralConfig.load(collateralType).normalizeTokenAmount(tokenAmount);

        (UD60x18 totalDeposited, UD60x18 totalAssigned) = account.getCollateralTotals(collateralType);

        UD60x18 availableForWithdrawal = totalDeposited.sub(totalAssigned);
        if (tokenWad.gt(availableForWithdrawal)) {
            revert Zaros_CollateralModule_InsufficientAccountCollateral(tokenWad.intoUint256());
        }

        account.collaterals[collateralType].decreaseAvailableCollateral(tokenWad);

        IERC20(collateralType).safeTransfer(msg.sender, tokenAmount);

        emit LogWithdrawal(accountId, collateralType, tokenAmount, msg.sender);
    }
}
