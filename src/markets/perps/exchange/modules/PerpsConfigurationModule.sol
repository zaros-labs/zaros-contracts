// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { IPerpsConfigurationModule } from "../interfaces/IPerpsConfigurationModule.sol";
import { PerpsConfiguration } from "../storage/PerpsConfiguration.sol";

// OpenZeppelin dependencies
import { Ownable } from "@openzeppelin/access/Ownable.sol";

abstract contract PerpsConfigurationModule is IPerpsConfigurationModule, Ownable {
    using PerpsConfiguration for PerpsConfiguration.Data;

    function isCollateralEnabled(address collateralType) external view override returns (bool) {
        PerpsConfiguration.Data storage perpsConfiguration = PerpsConfiguration.load();

        return perpsConfiguration.isCollateralEnabled(collateralType);
    }

    function setPerpsAccountToken(address perpsPerpsAccountToken) external {
        if (perpsPerpsAccountToken == address(0)) {
            revert Zaros_PerpsConfigurationModule_PerpsAccountTokenNotDefined();
        }

        PerpsConfiguration.Data storage perpsConfiguration = PerpsConfiguration.load();
        perpsConfiguration.perpsPerpsAccountToken = perpsPerpsAccountToken;
    }

    function setZaros(address zaros) external override {
        if (zaros == address(0)) {
            revert Zaros_PerpsConfigurationModule_ZarosNotDefined();
        }

        PerpsConfiguration.Data storage perpsConfiguration = PerpsConfiguration.load();
        perpsConfiguration.zaros = zaros;
    }

    function setIsEnabledCollateral(address collateralType, bool shouldEnable) external override onlyOwner {
        PerpsConfiguration.Data storage perpsConfiguration = PerpsConfiguration.load();

        perpsConfiguration.setIsCollateralEnabled(collateralType, shouldEnable);

        emit LogSetSupportedCollateral(msg.sender, collateralType, shouldEnable);
    }

    function __PerpsConfigurationModule_init(
        address perpsPerpsAccountToken,
        address rewardDistributor,
        address zaros
    )
        internal
    {
        PerpsConfiguration.Data storage perpsConfiguration = PerpsConfiguration.load();
        perpsConfiguration.perpsPerpsAccountToken = perpsPerpsAccountToken;
        perpsConfiguration.rewardDistributor = rewardDistributor;
        perpsConfiguration.zaros = zaros;
    }
}
