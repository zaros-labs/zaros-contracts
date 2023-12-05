// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { Constants } from "@zaros/utils/Constants.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { IPerpsConfigurationModule } from "../interfaces/IPerpsConfigurationModule.sol";
import { PerpsConfiguration } from "../storage/PerpsConfiguration.sol";
import { PerpsMarket } from "../storage/PerpsMarket.sol";
import { MarginCollateral } from "../storage/MarginCollateral.sol";
import { OrderFees } from "../storage/OrderFees.sol";
import { SettlementStrategy } from "../storage/SettlementStrategy.sol";

// OpenZeppelin Upgradeable dependencies
import { ERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";
import { Initializable } from "@openzeppelin-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/access/OwnableUpgradeable.sol";

// PRB Math dependencies
import { ud60x18 } from "@prb-math/UD60x18.sol";

/// @notice See {IPerpsConfigurationModule}.
abstract contract PerpsConfigurationModule is IPerpsConfigurationModule, Initializable, OwnableUpgradeable {
    using PerpsConfiguration for PerpsConfiguration.Data;
    using PerpsMarket for PerpsMarket.Data;
    using MarginCollateral for MarginCollateral.Data;

    /// @inheritdoc IPerpsConfigurationModule
    function getDepositCapForMarginCollateral(address collateralType) external view override returns (uint256) {
        MarginCollateral.Data storage marginCollateral = MarginCollateral.load(collateralType);

        return marginCollateral.getDepositCap().intoUint256();
    }

    /// @inheritdoc IPerpsConfigurationModule
    function setPerpsAccountToken(address perpsAccountToken) external {
        if (perpsAccountToken == address(0)) {
            revert Errors.PerpsAccountTokenNotDefined();
        }

        PerpsConfiguration.Data storage perpsConfiguration = PerpsConfiguration.load();
        perpsConfiguration.perpsAccountToken = perpsAccountToken;
    }

    /// @inheritdoc IPerpsConfigurationModule
    function setLiquidityEngine(address liquidityEngine) external override {
        if (liquidityEngine == address(0)) {
            revert Errors.LiquidityEngineNotDefined();
        }

        PerpsConfiguration.Data storage perpsConfiguration = PerpsConfiguration.load();
        perpsConfiguration.liquidityEngine = liquidityEngine;
    }

    function setChainlinkAddresses(address chainlinkForwarder, address chainlinkVerifier) external override onlyOwner {
        PerpsConfiguration.Data storage perpsConfiguration = PerpsConfiguration.load();
        perpsConfiguration.chainlinkForwarder = chainlinkForwarder;
        perpsConfiguration.chainlinkVerifier = chainlinkVerifier;
    }

    /// @inheritdoc IPerpsConfigurationModule
    function configureMarginCollateral(
        address collateralType,
        uint248 depositCap,
        address priceFeed
    )
        external
        override
        onlyOwner
    {
        try ERC20(collateralType).decimals() returns (uint8 decimals) {
            if (decimals > Constants.SYSTEM_DECIMALS || priceFeed == address(0)) {
                revert Errors.InvalidMarginCollateralConfiguration(collateralType, decimals, priceFeed);
            }
            MarginCollateral.configure(collateralType, depositCap, decimals, priceFeed);

            emit LogConfigureCollateral(msg.sender, collateralType, depositCap, decimals, priceFeed);
        } catch {
            revert Errors.InvalidMarginCollateralConfiguration(collateralType, 0, priceFeed);
        }
    }

    /// @inheritdoc IPerpsConfigurationModule
    function createPerpsMarket(
        uint128 marketId,
        string calldata name,
        string calldata symbol,
        uint128 maintenanceMarginRate,
        uint128 maxOpenInterest,
        uint128 minInitialMarginRate,
        SettlementStrategy.Data calldata marketOrderStrategy,
        SettlementStrategy.Data[] calldata customTriggerStrategies,
        OrderFees.Data calldata orderFees
    )
        external
        override
        onlyOwner
    {
        if (marketId == 0) {
            revert Errors.ZeroInput("marketId");
        }
        if (abi.encodePacked(name).length == 0) {
            revert Errors.ZeroInput("name");
        }
        if (abi.encodePacked(symbol).length == 0) {
            revert Errors.ZeroInput("symbol");
        }
        if (maintenanceMarginRate == 0) {
            revert Errors.ZeroInput("maintenanceMarginRate");
        }
        if (maxOpenInterest == 0) {
            revert Errors.ZeroInput("maxOpenInterest");
        }
        if (minInitialMarginRate == 0) {
            revert Errors.ZeroInput("minInitialMarginRate");
        }

        PerpsConfiguration.Data storage perpsConfiguration = PerpsConfiguration.load();

        PerpsMarket.create(
            marketId,
            name,
            symbol,
            maintenanceMarginRate,
            maxOpenInterest,
            minInitialMarginRate,
            marketOrderStrategy,
            customTriggerStrategies,
            orderFees
        );
        perpsConfiguration.addMarket(marketId);

        emit LogCreatePerpsMarket(
            marketId,
            name,
            symbol,
            maintenanceMarginRate,
            maxOpenInterest,
            minInitialMarginRate,
            marketOrderStrategy,
            orderFees
        );
    }

    /// @dev {PerpsConfigurationModule} UUPS initializer.
    function __PerpsConfigurationModule_init(
        address chainlinkForwader,
        address chainlinkVerifier,
        address perpsAccountToken,
        address rewardDistributor,
        address usdToken,
        address liquidityEngine
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
        perpsConfiguration.liquidityEngine = liquidityEngine;
    }
}
