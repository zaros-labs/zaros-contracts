// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { IPerpsMarketConfigurationModule } from "../interfaces/IPerpsMarketConfigurationModule.sol";
import { PerpsMarketConfiguration } from "../storage/PerpsMarketConfiguration.sol";

// OpenZeppelin dependencies
import { Ownable } from "@openzeppelin/access/Ownable.sol";

contract PerpsMarketConfigurationModule is IPerpsMarketConfigurationModule, Ownable {
    function setZaros(address zaros) external {
        PerpsMarketConfiguration.Data storage perpsMarketConfiguration = PerpsMarketConfiguration.load();
        perpsMarketConfiguration.zaros = zaros;
    }

    function setUsd(address zrsUsd) external {
        PerpsMarketConfiguration.Data storage perpsMarketConfiguration = PerpsMarketConfiguration.load();
        perpsMarketConfiguration.zrsUsd = zrsUsd;
    }

    function setSupportedMarket(address perpsMarket, bool enable) external onlyOwner {
        PerpsMarketConfiguration.Data storage perpsMarketConfiguration = PerpsMarketConfiguration.load();
        perpsMarketConfiguration.enabledPerpsMarkets[perpsMarket] = enable;

        emit LogSetSupportedMarket(perpsMarket, enable);
    }

    function setSupportedCollateral(address collateralType, bool enable) external onlyOwner {
        PerpsMarketConfiguration.Data storage perpsMarketConfiguration = PerpsMarketConfiguration.load();
        perpsMarketConfiguration.enabledCollateralTypes[collateralType] = enable;

        emit LogSetSupportedCollateral(msg.sender, collateralType, enable);
    }
}
