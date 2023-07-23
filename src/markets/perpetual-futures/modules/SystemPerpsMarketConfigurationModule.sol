// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { ISystemPerpsMarketConfigurationModule } from "../interfaces/ISystemPerpsMarketConfigurationModule.sol";
import { SystemPerpsMarketConfiguration } from "../storage/SystemPerpsMarketConfiguration.sol";

// OpenZeppelin dependencies
import { Ownable } from "@openzeppelin/access/Ownable.sol";

contract SystemPerpsMarketConfigurationModule is ISystemPerpsMarketConfigurationModule, Ownable {
    function setZaros(address zaros) external {
        SystemPerpsMarketConfiguration.Data storage systemPerpsMarketConfiguration =
            SystemPerpsMarketConfiguration.load();
        systemPerpsMarketConfiguration.zaros = zaros;
    }

    function setUsd(address zrsUsd) external {
        SystemPerpsMarketConfiguration.Data storage systemPerpsMarketConfiguration =
            SystemPerpsMarketConfiguration.load();
        systemPerpsMarketConfiguration.zrsUsd = zrsUsd;
    }

    function setSupportedMarket(address perpsMarket, bool enable) external onlyOwner {
        SystemPerpsMarketConfiguration.Data storage systemPerpsMarketConfiguration =
            SystemPerpsMarketConfiguration.load();
        systemPerpsMarketConfiguration.enabledPerpsMarkets[perpsMarket] = enable;

        emit LogSetSupportedMarket(perpsMarket, enable);
    }

    function setSupportedCollateral(address collateralType, bool enable) external onlyOwner {
        SystemPerpsMarketConfiguration.Data storage systemPerpsMarketConfiguration =
            SystemPerpsMarketConfiguration.load();
        systemPerpsMarketConfiguration.enabledCollateralTypes[collateralType] = enable;

        emit LogSetSupportedCollateral(msg.sender, collateralType, enable);
    }

    function __SystemPerpsMarketConfigurationModule_init(address zaros, address zrsUsd) internal {
        SystemPerpsMarketConfiguration.Data storage systemPerpsMarketConfiguration =
            SystemPerpsMarketConfiguration.load();
        systemPerpsMarketConfiguration.zaros = zaros;
        systemPerpsMarketConfiguration.zrsUsd = zrsUsd;
    }
}
