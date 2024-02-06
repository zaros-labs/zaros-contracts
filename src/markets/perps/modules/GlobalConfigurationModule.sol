// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { Constants } from "@zaros/utils/Constants.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { CreatePerpMarketParams, IGlobalConfigurationModule } from "../interfaces/IGlobalConfigurationModule.sol";
import { GlobalConfiguration } from "../storage/GlobalConfiguration.sol";
import { PerpMarket } from "../storage/PerpMarket.sol";
import { MarginCollateralConfiguration } from "../storage/MarginCollateralConfiguration.sol";
import { MarketConfiguration } from "../storage/MarketConfiguration.sol";
import { OrderFees } from "../storage/OrderFees.sol";
import { SettlementConfiguration } from "../storage/SettlementConfiguration.sol";

// OpenZeppelin Upgradeable dependencies
import { ERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";
import { Initializable } from "@openzeppelin-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/access/OwnableUpgradeable.sol";

// PRB Math dependencies
import { ud60x18 } from "@prb-math/UD60x18.sol";

/// @notice See {IGlobalConfigurationModule}.
contract GlobalConfigurationModule is IGlobalConfigurationModule, Initializable, OwnableUpgradeable {
    using GlobalConfiguration for GlobalConfiguration.Data;
    using PerpMarket for PerpMarket.Data;
    using MarginCollateralConfiguration for MarginCollateralConfiguration.Data;
    using MarketConfiguration for MarketConfiguration.Data;

    constructor() {
        _disableInitializers();
    }

    /// TODO: Create inheritable AuthModule
    /// @dev The Ownable contract is initialized at the DiamondCutModule.
    /// @dev {GlobalConfigurationModule} UUPS initializer.
    function initialize(
        address perpsAccountToken,
        address rewardDistributor,
        address usdToken,
        address liquidityEngine
    )
        external
        initializer
    {
        GlobalConfiguration.Data storage globalConfiguration = GlobalConfiguration.load();
        globalConfiguration.perpsAccountToken = perpsAccountToken;
        globalConfiguration.rewardDistributor = rewardDistributor;
        globalConfiguration.usdToken = usdToken;
        globalConfiguration.liquidityEngine = liquidityEngine;
    }

    /// @inheritdoc IGlobalConfigurationModule
    function getDepositCapForMarginCollateralConfiguration(address collateralType)
        external
        view
        override
        returns (uint256)
    {
        MarginCollateralConfiguration.Data storage marginCollateralConfiguration =
            MarginCollateralConfiguration.load(collateralType);

        return marginCollateralConfiguration.depositCap;
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
        uint128 depositCap,
        uint120 loanToValue,
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
            MarginCollateralConfiguration.configure(collateralType, depositCap, loanToValue, decimals, priceFeed);

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
        if (params.priceAdapter == address(0)) {
            revert Errors.ZeroInput("priceAdapter");
        }
        if (params.maintenanceMarginRateX18 == 0) {
            revert Errors.ZeroInput("maintenanceMarginRateX18");
        }
        if (params.maxOpenInterest == 0) {
            revert Errors.ZeroInput("maxOpenInterest");
        }
        if (params.minInitialMarginRateX18 == 0) {
            revert Errors.ZeroInput("minInitialMarginRateX18");
        }

        GlobalConfiguration.Data storage globalConfiguration = GlobalConfiguration.load();

        PerpMarket.create(
            params.marketId,
            params.name,
            params.symbol,
            params.priceAdapter,
            params.minInitialMarginRateX18,
            params.maintenanceMarginRateX18,
            params.maxOpenInterest,
            params.skewScale,
            params.maxFundingVelocity,
            params.marketOrderConfiguration,
            params.customTriggerStrategies,
            params.orderFees
        );
        globalConfiguration.addMarket(params.marketId);

        emit LogCreatePerpMarket(
            params.marketId,
            params.name,
            params.symbol,
            // params.priceAdapter,
            params.maintenanceMarginRateX18,
            params.maxOpenInterest,
            params.minInitialMarginRateX18,
            params.marketOrderConfiguration,
            params.customTriggerStrategies,
            params.orderFees
        );
    }

    /// @inheritdoc IGlobalConfigurationModule
    function updatePerpMarketConfiguration(
        uint128 marketId,
        string calldata name,
        string calldata symbol,
        address priceAdapter,
        uint128 minInitialMarginRateX18,
        uint128 maintenanceMarginRateX18,
        uint128 maxOpenInterest,
        uint128 maxFundingVelocity,
        uint256 skewScale,
        OrderFees.Data memory orderFees
    )
        external
        override
        onlyOwner
    {
        PerpMarket.Data storage perpMarket = PerpMarket.load(marketId);
        MarketConfiguration.Data storage perpMarketConfiguration = perpMarket.configuration;

        if (!perpMarket.initialized) {
            revert Errors.PerpMarketNotInitialized(marketId);
        }

        if (abi.encodePacked(name).length == 0) {
            revert Errors.ZeroInput("name");
        }
        if (abi.encodePacked(symbol).length == 0) {
            revert Errors.ZeroInput("symbol");
        }
        if (priceAdapter == address(0)) {
            revert Errors.ZeroInput("priceAdapter");
        }
        if (minInitialMarginRateX18 == 0) {
            revert Errors.ZeroInput("minInitialMarginRateX18");
        }

        if (maintenanceMarginRateX18 == 0) {
            revert Errors.ZeroInput("maintenanceMarginRateX18");
        }
        if (skewScale == 0) {
            revert Errors.ZeroInput("skewScale");
        }

        perpMarketConfiguration.update(
            name,
            symbol,
            priceAdapter,
            minInitialMarginRateX18,
            maintenanceMarginRateX18,
            maxOpenInterest,
            maxFundingVelocity,
            skewScale,
            orderFees
        );

        emit LogConfigurePerpMarket(
            marketId,
            name,
            symbol,
            minInitialMarginRateX18,
            maintenanceMarginRateX18,
            maxOpenInterest,
            maxFundingVelocity,
            skewScale,
            orderFees
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
}
