// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { ParameterError } from "@zaros/utils/Errors.sol";
import { IPerpsConfigurationModule } from "../interfaces/IPerpsConfigurationModule.sol";
import { OrderFees } from "../storage/OrderFees.sol";
import { PerpsConfiguration } from "../storage/PerpsConfiguration.sol";
import { PerpsMarket } from "../storage/PerpsMarket.sol";

// OpenZeppelin Upgradeable dependencies
import { Initializable } from "@openzeppelin-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/access/OwnableUpgradeable.sol";

/// @notice See {IPerpsConfigurationModule}.
abstract contract PerpsConfigurationModule is IPerpsConfigurationModule, Initializable, OwnableUpgradeable {
    using PerpsConfiguration for PerpsConfiguration.Data;
    using PerpsMarket for PerpsMarket.Data;

    /// @inheritdoc IPerpsConfigurationModule
    function isCollateralEnabled(address collateralType) external view override returns (bool) {
        PerpsConfiguration.Data storage perpsConfiguration = PerpsConfiguration.load();

        return perpsConfiguration.isCollateralEnabled(collateralType);
    }

    /// @inheritdoc IPerpsConfigurationModule
    function setPerpsAccountToken(address perpsAccountToken) external {
        if (perpsAccountToken == address(0)) {
            revert Zaros_PerpsConfigurationModule_PerpsAccountTokenNotDefined();
        }

        PerpsConfiguration.Data storage perpsConfiguration = PerpsConfiguration.load();
        perpsConfiguration.perpsAccountToken = perpsAccountToken;
    }

    /// @inheritdoc IPerpsConfigurationModule
    function setZaros(address zaros) external override {
        if (zaros == address(0)) {
            revert Zaros_PerpsConfigurationModule_ZarosNotDefined();
        }

        PerpsConfiguration.Data storage perpsConfiguration = PerpsConfiguration.load();
        perpsConfiguration.zaros = zaros;
    }

    function setChainlinkAddresses(address chainlinkForwarder, address chainlinkVerifier) external override onlyOwner {
        PerpsConfiguration.Data storage perpsConfiguration = PerpsConfiguration.load();
        perpsConfiguration.chainlinkForwarder = chainlinkForwarder;
        perpsConfiguration.chainlinkVerifier = chainlinkVerifier;
    }

    /// @inheritdoc IPerpsConfigurationModule
    function setIsCollateralEnabled(address collateralType, bool shouldEnable) external override onlyOwner {
        PerpsConfiguration.Data storage perpsConfiguration = PerpsConfiguration.load();

        perpsConfiguration.setIsCollateralEnabled(collateralType, shouldEnable);

        emit LogSetSupportedCollateral(msg.sender, collateralType, shouldEnable);
    }

    /// @inheritdoc IPerpsConfigurationModule
    function configurePriceFeed(address collateralType, address priceFeed) external override onlyOwner {
        PerpsConfiguration.Data storage perpsConfiguration = PerpsConfiguration.load();

        perpsConfiguration.configurePriceFeed(collateralType, priceFeed);

        emit LogConfigurePriceFeed(msg.sender, collateralType, priceFeed);
    }

    /// @inheritdoc IPerpsConfigurationModule
    function createPerpsMarket(
        uint128 marketId,
        string calldata name,
        string calldata symbol,
        bytes32 streamId,
        address priceFeed,
        uint128 maintenanceMarginRate,
        uint128 maxOpenInterest,
        uint128 minInitialMarginRate,
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
        } else if (minInitialMarginRate == 0) {
            revert ParameterError.Zaros_InvalidParameter("minInitialMarginRate", "minInitialMarginRate can't be zero");
        }

        PerpsConfiguration.Data storage perpsConfiguration = PerpsConfiguration.load();

        PerpsMarket.create(
            marketId,
            name,
            symbol,
            streamId,
            priceFeed,
            maintenanceMarginRate,
            maxOpenInterest,
            minInitialMarginRate,
            orderFees
        );
        perpsConfiguration.addMarket(marketId);

        emit LogCreatePerpsMarket(marketId, name, symbol);
    }

    /// @dev {PerpsConfigurationModule} UUPS initializer.
    function __PerpsConfigurationModule_init(
        address chainlinkForwader,
        address chainlinkVerifier,
        address perpsAccountToken,
        address rewardDistributor,
        address usdToken,
        address zaros
    )
        internal
        onlyInitializing
    {
        PerpsConfiguration.Data storage perpsConfiguration = PerpsConfiguration.load();
        perpsConfiguration.chainlinkForwarder = chainlinkForwader;
        perpsConfiguration.chainlinkVerifier = chainlinkVerifier;
        perpsConfiguration.perpsAccountToken = perpsAccountToken;
        perpsConfiguration.rewardDistributor = rewardDistributor;
        perpsConfiguration.usdToken = usdToken;
        perpsConfiguration.zaros = zaros;
    }
}
