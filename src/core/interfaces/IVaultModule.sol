//SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// PRB Math dependencies
import { UD60x18 } from "@prb-math/UD60x18.sol";

interface IVaultModule {
    error Zaros_VaultModule_CapacityLocked(address marketAddress);

    error Zaros_VaultModule_InvalidCollateralAmount();

    event LogDelegateCollateral(
        uint128 indexed accountId, address collateralType, uint256 amount, address indexed sender
    );

    function getPositionCollateralRatio(uint128 accountId, address collateralType) external returns (uint256 ratio);

    function getPositionDebt(uint128 accountId, address collateralType) external returns (int256 debt);

    function getPositionCollateral(
        uint128 accountId,
        address collateralType
    )
        external
        view
        returns (uint256 collateralAmount, uint256 collateralValue);

    function getPosition(
        uint128 accountId,
        address collateralType
    )
        external
        returns (uint256 collateralAmount, uint256 collateralValue, int256 debt, uint256 collateralizationRatio);

    function getVaultDebt(address collateralType) external returns (int256 debt);

    function getVaultCollateral(address collateralType)
        external
        returns (uint256 collateralAmount, uint256 collateralValue);

    function getVaultCollateralRatio(address collateralType) external returns (uint256 ratio);

    function delegateCollateral(uint128 accountId, address collateralType, UD60x18 newCollateralAmount) external;
}
