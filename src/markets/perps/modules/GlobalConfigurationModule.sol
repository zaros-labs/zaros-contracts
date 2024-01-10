// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { Constants } from "@zaros/utils/Constants.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { CreatePerpMarketParams, IGlobalConfigurationModule } from "../interfaces/IGlobalConfigurationModule.sol";
import { GlobalConfiguration } from "../storage/GlobalConfiguration.sol";
import { PerpMarket } from "../storage/PerpMarket.sol";
import { MarginCollateralConfiguration } from "../storage/MarginCollateralConfiguration.sol";
import { OrderFees } from "../storage/OrderFees.sol";
import { SettlementConfiguration } from "../storage/SettlementConfiguration.sol";

// OpenZeppelin Upgradeable dependencies
import { ERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";
import { Initializable } from "@openzeppelin-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/access/OwnableUpgradeable.sol";

// PRB Math dependencies
import { ud60x18 } from "@prb-math/UD60x18.sol";

/// @notice See {IGlobalConfigurationModule}.
abstract contract GlobalConfigurationModule is IGlobalConfigurationModule, Initializable, OwnableUpgradeable {
    using GlobalConfiguration for GlobalConfiguration.Data;
    using PerpMarket for PerpMarket.Data;
    using MarginCollateralConfiguration for MarginCollateralConfiguration.Data;

    /// @inheritdoc IGlobalConfigurationModule
    function getDepositCapForMarginCollateralConfiguration(address collateralType)
        external
        view
        override
        returns (uint256)
    {
        MarginCollateralConfiguration.Data storage marginCollateralConfiguration =
            MarginCollateralConfiguration.load(collateralType);

        return marginCollateralConfiguration.getDepositCap().intoUint256();
    }

    /// @inheritdoc IGlobalConfigurationModule
    function setPerpsAccountToken(address perpsAccountToken) external {
        if (perpsAccountToken == address(0)) {
            revert Errors.PerpsAccountTokenNotDefined();
        }

        GlobalConfiguration.Data storage globalConfiguration = GlobalConfiguration.load();
        globalConfiguration.perpsAccountToken = perpsAccountToken;
    }

    /// @inheritdoc IGlobalConfigurationModule
    function setLiquidityEngine(address liquidityEngine) external override {
        if (liquidityEngine == address(0)) {
            revert Errors.LiquidityEngineNotDefined();
        }

        GlobalConfiguration.Data storage globalConfiguration = GlobalConfiguration.load();
        globalConfiguration.liquidityEngine = liquidityEngine;
    }

    /// @inheritdoc IGlobalConfigurationModule
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
            MarginCollateralConfiguration.configure(collateralType, depositCap, decimals, priceFeed);

            emit LogConfigureCollateral(msg.sender, collateralType, depositCap, decimals, priceFeed);
        } catch {
            revert Errors.InvalidMarginCollateralConfiguration(collateralType, 0, priceFeed);
        }
    }

    /// @inheritdoc IGlobalConfigurationModule
    function configureCollateralPriority(address[] calldata collateralTypes) external override onlyOwner {
        if (collateralTypes.length == 0) {
            revert Errors.ZeroInput("collateralTypes");
        }

        GlobalConfiguration.Data storage globalConfiguration = GlobalConfiguration.load();
        globalConfiguration.configureCollateralPriority(collateralTypes);
    }

    /// @inheritdoc IGlobalConfigurationModule
    function removeCollateralFromPriorityList(address collateralType) external override onlyOwner {
        if (collateralType == address(0)) {
            revert Errors.ZeroInput("collateralType");
        }

        GlobalConfiguration.Data storage globalConfiguration = GlobalConfiguration.load();
        globalConfiguration.removeCollateralTypeFromPriorityList(collateralType);
    }

    /// @inheritdoc IGlobalConfigurationModule
    function configureSystemParameters(
        uint128 maxPositionsPerAccount,
        uint128 marketOrderMaxLifetime
    )
        external
        override
        onlyOwner
    {
        if (maxPositionsPerAccount == 0) {
            revert Errors.ZeroInput("maxPositionsPerAccount");
        }

        GlobalConfiguration.Data storage globalConfiguration = GlobalConfiguration.load();

        globalConfiguration.maxPositionsPerAccount = maxPositionsPerAccount;
        globalConfiguration.marketOrderMaxLifetime = marketOrderMaxLifetime;
    }

    /// @inheritdoc IGlobalConfigurationModule
    function createPerpMarket(CreatePerpMarketParams calldata params) external override onlyOwner {
        if (params.marketId == 0) {
            revert Errors.ZeroInput("marketId");
        }
        if (abi.encodePacked(params.name).length == 0) {
            revert Errors.ZeroInput("name");
        }
        if (abi.encodePacked(params.symbol).length == 0) {
            revert Errors.ZeroInput("symbol");
        }
        if (params.maintenanceMarginRate == 0) {
            revert Errors.ZeroInput("maintenanceMarginRate");
        }
        if (params.maxOpenInterest == 0) {
            revert Errors.ZeroInput("maxOpenInterest");
        }
        if (params.minInitialMarginRate == 0) {
            revert Errors.ZeroInput("minInitialMarginRate");
        }

        GlobalConfiguration.Data storage globalConfiguration = GlobalConfiguration.load();

        PerpMarket.create(
            params.marketId,
            params.name,
            params.symbol,
            params.minInitialMarginRate,
            params.maintenanceMarginRate,
            params.maxOpenInterest,
            params.skewScale,
            params.maxFundingVelocity,
            params.marketOrderStrategy,
            params.customTriggerStrategies,
            params.orderFees
        );
        globalConfiguration.addMarket(params.marketId);

        emit LogCreatePerpMarket(
            params.marketId,
            params.name,
            params.symbol,
            params.maintenanceMarginRate,
            params.maxOpenInterest,
            params.minInitialMarginRate,
            params.marketOrderStrategy,
            params.customTriggerStrategies,
            params.orderFees
        );
    }

    function updatePerpMarketStatus(uint128 marketId, bool enable) external override onlyOwner {
        GlobalConfiguration.Data storage globalConfiguration = GlobalConfiguration.load();
        PerpMarket.Data storage perpMarket = PerpMarket.load(marketId);

        if (!perpMarket.initialized) {
            revert Errors.PerpMarketNotInitialized(marketId);
        }

        if (enable) {
            globalConfiguration.addMarket(marketId);

            emit LogEnablePerpMarket(marketId);
        } else {
            globalConfiguration.removeMarket(marketId);

            emit LogDisablePerpMarket(marketId);
        }
    }

    /// @dev {GlobalConfigurationModule} UUPS initializer.
    function __GlobalConfigurationModule_init(
        address perpsAccountToken,
        address rewardDistributor,
        address usdToken,
        address liquidityEngine
    )
        internal
        onlyInitializing
    {
        GlobalConfiguration.Data storage globalConfiguration = GlobalConfiguration.load();
        globalConfiguration.perpsAccountToken = perpsAccountToken;
        globalConfiguration.rewardDistributor = rewardDistributor;
        globalConfiguration.usdToken = usdToken;
        globalConfiguration.liquidityEngine = liquidityEngine;
    }
}
