//SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

// Zaros dependencies
import { CollateralConfig } from "../storage/CollateralConfig.sol";

// PRB Math dependencies
import { UD60x18 } from "@prb-math/UD60x18.sol";

interface ICollateralModule {
    error Zaros_CollateralModule_InvalidConfiguration(CollateralConfig.Data config);

    error Zaros_CollateralModule_InsufficientAccountCollateral(uint256 amount);

    event LogConfigureCollateral(address indexed collateralType, CollateralConfig.Data config);

    event LogDeposit(
        uint128 indexed accountId, address indexed collateralType, uint256 tokenAmount, address indexed sender
    );

    event LogWithdrawal(
        uint128 indexed accountId, address indexed collateralType, uint256 tokenAmount, address indexed sender
    );

    function getCollateralConfigs(bool hideDisabled)
        external
        view
        returns (CollateralConfig.Data[] memory collaterals);

    function getCollateralConfig(address collateralType)
        external
        view
        returns (CollateralConfig.Data memory collateral);

    function getCollateralPrice(address collateralType) external view returns (uint256 price);

    function getAccountCollateral(
        uint128 accountId,
        address collateralType
    )
        external
        view
        returns (UD60x18 totalDeposited, UD60x18 totalAssigned);

    function getAccountAvailableCollateral(
        uint128 accountId,
        address collateralType
    )
        external
        view
        returns (uint256 amount);

    function configureCollateral(CollateralConfig.Data memory config) external;

    function deposit(uint128 accountId, address collateralType, uint256 tokenAmount) external;

    function withdraw(uint128 accountId, address collateralType, uint256 tokenAmount) external;
}
