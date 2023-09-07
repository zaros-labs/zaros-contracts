// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { ISystemPerpsMarketsConfigurationModule } from "../interfaces/ISystemPerpsMarketsConfigurationModule.sol";
import { SystemPerpsMarketsConfiguration } from "../storage/SystemPerpsMarketsConfiguration.sol";

// OpenZeppelin dependencies
import { Ownable } from "@openzeppelin/access/Ownable.sol";

contract SystemPerpsMarketsConfigurationModule is ISystemPerpsMarketsConfigurationModule, Ownable {
    function zaros() external view returns (address) {
        SystemPerpsMarketsConfiguration storage systemPerpsMarketConfiguration = SystemPerpsMarketConfiguration.load();

        return systemPerpsMarketConfiguration.zaros;
    }

    function accountToken() external view returns (address) {
        SystemPerpsMarketsConfiguration storage systemPerpsMarketConfiguration = SystemPerpsMarketConfiguration.load();

        return systemPerpsMarketConfiguration.accountToken;
    }

    function isCollateralEnabled(address collateralType) external view returns (bool) {
        SystemPerpsMarketsConfiguration.Data storage systemPerpsMarketsConfiguration =
            SystemPerpsMarketsConfiguration.load();

        return systemPerpsMarketsConfiguration.isCollateralEnabled(collateralType);
    }

    function setZaros(address zaros) external {
        SystemPerpsMarketsConfiguration.Data storage systemPerpsMarketsConfiguration =
            SystemPerpsMarketsConfiguration.load();
        systemPerpsMarketsConfiguration.zaros = zaros;
    }

    function setIsEnabledCollateral(address collateralType, bool shouldEnable) external onlyOwner {
        SystemPerpsMarketsConfiguration.Data storage systemPerpsMarketsConfiguration =
            SystemPerpsMarketsConfiguration.load();

        systemPerpsMarketsConfiguration.setIsCollateralEnabled(collateralType, shouldEnable);

        emit LogSetSupportedCollateral(msg.sender, collateralType, shouldEnable);
    }

    function __SystemPerpsMarketsConfigurationModule_init(
        address zaros,
        address zrsUsd,
        address rewardDistributor
    )
        internal
    {
        SystemPerpsMarketsConfiguration.Data storage systemPerpsMarketsConfiguration =
            SystemPerpsMarketsConfiguration.load();
        systemPerpsMarketsConfiguration.zaros = zaros;
        systemPerpsMarketsConfiguration.zrsUsd = zrsUsd;
        systemPerpsMarketsConfiguration.rewardDistributor = rewardDistributor;
    }
}
