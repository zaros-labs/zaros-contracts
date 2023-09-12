// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { ISystemPerpsMarketsConfigurationModule } from "../interfaces/ISystemPerpsMarketsConfigurationModule.sol";
import { SystemPerpsMarketsConfiguration } from "../storage/SystemPerpsMarketsConfiguration.sol";

// OpenZeppelin dependencies
import { Ownable } from "@openzeppelin/access/Ownable.sol";

contract SystemPerpsMarketsConfigurationModule is ISystemPerpsMarketsConfigurationModule, Ownable {
    using SystemPerpsMarketsConfiguration for SystemPerpsMarketsConfiguration.Data;

    function isCollateralEnabled(address collateralType) external view override returns (bool) {
        SystemPerpsMarketsConfiguration.Data storage systemPerpsMarketsConfiguration =
            SystemPerpsMarketsConfiguration.load();

        return systemPerpsMarketsConfiguration.isCollateralEnabled(collateralType);
    }

    function setAccountToken(address accountToken) external {
        if (accountToken == address(0)) {
            revert Zaros_SystemPerpsMarketsConfigurationModule_AccountTokenNotDefined();
        }

        SystemPerpsMarketsConfiguration.Data storage systemPerpsMarketsConfiguration =
            SystemPerpsMarketsConfiguration.load();
        systemPerpsMarketsConfiguration.accountToken = accountToken;
    }

    function setZaros(address zaros) external override {
        if (zaros == address(0)) {
            revert Zaros_SystemPerpsMarketsConfigurationModule_ZarosNotDefined();
        }

        SystemPerpsMarketsConfiguration.Data storage systemPerpsMarketsConfiguration =
            SystemPerpsMarketsConfiguration.load();
        systemPerpsMarketsConfiguration.zaros = zaros;
    }

    function setIsEnabledCollateral(address collateralType, bool shouldEnable) external override onlyOwner {
        SystemPerpsMarketsConfiguration.Data storage systemPerpsMarketsConfiguration =
            SystemPerpsMarketsConfiguration.load();

        systemPerpsMarketsConfiguration.setIsCollateralEnabled(collateralType, shouldEnable);

        emit LogSetSupportedCollateral(msg.sender, collateralType, shouldEnable);
    }

    function __SystemPerpsMarketsConfigurationModule_init(
        address accountToken,
        address rewardDistributor,
        address zaros
    )
        internal
    {
        SystemPerpsMarketsConfiguration.Data storage systemPerpsMarketsConfiguration =
            SystemPerpsMarketsConfiguration.load();
        systemPerpsMarketsConfiguration.accountToken = accountToken;
        systemPerpsMarketsConfiguration.rewardDistributor = rewardDistributor;
        systemPerpsMarketsConfiguration.zaros = zaros;
    }
}
