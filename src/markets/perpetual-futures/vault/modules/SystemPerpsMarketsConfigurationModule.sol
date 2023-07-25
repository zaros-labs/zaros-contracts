// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { ISystemPerpsMarketsConfigurationModule } from "../interfaces/ISystemPerpsMarketsConfigurationModule.sol";
import { SystemPerpsMarketsConfiguration } from "../storage/SystemPerpsMarketsConfiguration.sol";

// OpenZeppelin dependencies
import { Ownable } from "@openzeppelin/access/Ownable.sol";

contract SystemPerpsMarketsConfigurationModule is ISystemPerpsMarketsConfigurationModule, Ownable {
    function isCollateralEnabled(address collateralType) external view returns (bool) {
        SystemPerpsMarketsConfiguration.Data storage systemPerpsMarketsConfiguration =
            SystemPerpsMarketsConfiguration.load();

        return systemPerpsMarketsConfiguration.enabledCollateralTypes[collateralType];
    }

    function isPerpsMarketEnabled(address perpsMarket) external view returns (bool) {
        SystemPerpsMarketsConfiguration.Data storage systemPerpsMarketsConfiguration =
            SystemPerpsMarketsConfiguration.load();

        return systemPerpsMarketsConfiguration.enabledPerpsMarkets[perpsMarket];
    }

    function setZaros(address zaros) external {
        SystemPerpsMarketsConfiguration.Data storage systemPerpsMarketsConfiguration =
            SystemPerpsMarketsConfiguration.load();
        systemPerpsMarketsConfiguration.zaros = zaros;
    }

    function setUsd(address zrsUsd) external {
        SystemPerpsMarketsConfiguration.Data storage systemPerpsMarketsConfiguration =
            SystemPerpsMarketsConfiguration.load();
        systemPerpsMarketsConfiguration.zrsUsd = zrsUsd;
    }

    function setSupportedMarket(address perpsMarket, bool enable) external onlyOwner {
        SystemPerpsMarketsConfiguration.Data storage systemPerpsMarketsConfiguration =
            SystemPerpsMarketsConfiguration.load();
        systemPerpsMarketsConfiguration.enabledPerpsMarkets[perpsMarket] = enable;

        emit LogSetSupportedMarket(perpsMarket, enable);
    }

    function setSupportedCollateral(address collateralType, bool enable) external onlyOwner {
        SystemPerpsMarketsConfiguration.Data storage systemPerpsMarketsConfiguration =
            SystemPerpsMarketsConfiguration.load();
        systemPerpsMarketsConfiguration.enabledCollateralTypes[collateralType] = enable;

        emit LogSetSupportedCollateral(msg.sender, collateralType, enable);
    }

    function __SystemPerpsMarketsConfigurationModule_init(address zaros, address zrsUsd) internal {
        SystemPerpsMarketsConfiguration.Data storage systemPerpsMarketsConfiguration =
            SystemPerpsMarketsConfiguration.load();
        systemPerpsMarketsConfiguration.zaros = zaros;
        systemPerpsMarketsConfiguration.zrsUsd = zrsUsd;
    }
}
