// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { ParameterError } from "@zaros/utils/Errors.sol";
import { IPerpsConfigurationModule } from "../interfaces/IPerpsConfigurationModule.sol";
import { OrderFees } from "../storage/OrderFees.sol";
import { PerpsConfiguration } from "../storage/PerpsConfiguration.sol";
import { PerpsMarket } from "../storage/PerpsMarket.sol";

// OpenZeppelin dependencies
import { Ownable } from "@openzeppelin/access/Ownable.sol";

abstract contract PerpsConfigurationModule is IPerpsConfigurationModule, Ownable {
    using PerpsConfiguration for PerpsConfiguration.Data;
    using PerpsMarket for PerpsMarket.Data;

    function isCollateralEnabled(address collateralType) external view override returns (bool) {
        PerpsConfiguration.Data storage perpsConfiguration = PerpsConfiguration.load();

        return perpsConfiguration.isCollateralEnabled(collateralType);
    }

    function setPerpsAccountToken(address perpsAccountToken) external {
        if (perpsAccountToken == address(0)) {
            revert Zaros_PerpsConfigurationModule_PerpsAccountTokenNotDefined();
        }

        PerpsConfiguration.Data storage perpsConfiguration = PerpsConfiguration.load();
        perpsConfiguration.perpsAccountToken = perpsAccountToken;
    }

    function setZaros(address zaros) external override {
        if (zaros == address(0)) {
            revert Zaros_PerpsConfigurationModule_ZarosNotDefined();
        }

        PerpsConfiguration.Data storage perpsConfiguration = PerpsConfiguration.load();
        perpsConfiguration.zaros = zaros;
    }

    function setIsCollateralEnabled(address collateralType, bool shouldEnable) external override onlyOwner {
        PerpsConfiguration.Data storage perpsConfiguration = PerpsConfiguration.load();

        perpsConfiguration.setIsCollateralEnabled(collateralType, shouldEnable);

        emit LogSetSupportedCollateral(msg.sender, collateralType, shouldEnable);
    }

    /// @inheritdoc IPerpsConfigurationModule
    function createPerpsMarket(
        uint128 marketId,
        string calldata name,
        string calldata symbol,
        address priceFeed,
        uint128 maxLeverage,
        OrderFees.Data calldata orderFees
    )
        external
        override
        onlyOwner
    {
        if (marketId == 0) {
            revert ParameterError.Zaros_InvalidParameter("marketId", "marketId can't be zero");
        } else if (priceFeed == address(0)) {
            revert ParameterError.Zaros_InvalidParameter("priceFeed", "priceFeed can't be the zero address");
        } else if (maxLeverage == 0) {
            revert ParameterError.Zaros_InvalidParameter("maxLeverage", "maxLeverage can't be zero");
        }

        PerpsConfiguration.Data storage perpsConfiguration = PerpsConfiguration.load();

        PerpsMarket.createAndVerifyId(marketId, name, symbol, priceFeed, maxLeverage, orderFees);
        perpsConfiguration.addMarket(marketId);

        emit LogCreatePerpsMarket(marketId, name, symbol);
    }

    function __PerpsConfigurationModule_init(
        address perpsAccountToken,
        address rewardDistributor,
        address zaros
    )
        internal
    {
        PerpsConfiguration.Data storage perpsConfiguration = PerpsConfiguration.load();
        perpsConfiguration.perpsAccountToken = perpsAccountToken;
        perpsConfiguration.rewardDistributor = rewardDistributor;
        perpsConfiguration.zaros = zaros;
    }
}
