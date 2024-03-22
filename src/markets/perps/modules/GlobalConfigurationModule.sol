// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { Constants } from "@zaros/utils/Constants.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { IGlobalConfigurationModule } from "../interfaces/IGlobalConfigurationModule.sol";
import { GlobalConfiguration } from "../storage/GlobalConfiguration.sol";
import { PerpMarket } from "../storage/PerpMarket.sol";
import { MarginCollateralConfiguration } from "../storage/MarginCollateralConfiguration.sol";
import { MarketConfiguration } from "../storage/MarketConfiguration.sol";
import { OrderFees } from "../storage/OrderFees.sol";
import { SettlementConfiguration } from "../storage/SettlementConfiguration.sol";

// OpenZeppelin Upgradeable dependencies
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";
import { ERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";
import { Initializable } from "@openzeppelin-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/access/OwnableUpgradeable.sol";

// PRB Math dependencies
import { UD60x18, ud60x18, UNIT as UD_UNIT } from "@prb-math/UD60x18.sol";

/// @notice See {IGlobalConfigurationModule}.
contract GlobalConfigurationModule is IGlobalConfigurationModule, Initializable, OwnableUpgradeable {
    using EnumerableSet for EnumerableSet.UintSet;
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
    function getAccountsWithActivePositions(
        uint256 lowerBound,
        uint256 upperBound
    )
        external
        view
        override
        returns (uint128[] memory accountsIds)
    {
        GlobalConfiguration.Data storage globalConfiguration = GlobalConfiguration.load();

        for (uint256 i = lowerBound; i < upperBound; i++) {
            accountsIds[i] = uint128(globalConfiguration.accountsIdsWithActivePositions.at(i));
        }
    }

    /// @inheritdoc IGlobalConfigurationModule
    function getMarginCollateralConfiguration(address collateralType)
        external
        pure
        override
        returns (MarginCollateralConfiguration.Data memory)
    {
        MarginCollateralConfiguration.Data memory marginCollateralConfiguration =
            MarginCollateralConfiguration.load(collateralType);

        return marginCollateralConfiguration;
    }

    /// @inheritdoc IGlobalConfigurationModule
    function setPerpsAccountToken(address perpsAccountToken) external {
        if (perpsAccountToken == address(0)) {
            revert Errors.PerpsAccountTokenNotDefined();
        }

        GlobalConfiguration.Data storage globalConfiguration = GlobalConfiguration.load();
        globalConfiguration.perpsAccountToken = perpsAccountToken;

        emit LogSetPerpsAccountToken(msg.sender, perpsAccountToken);
    }

    /// @inheritdoc IGlobalConfigurationModule
    function setLiquidityEngine(address liquidityEngine) external override {
        if (liquidityEngine == address(0)) {
            revert Errors.LiquidityEngineNotDefined();
        }

        GlobalConfiguration.Data storage globalConfiguration = GlobalConfiguration.load();
        globalConfiguration.liquidityEngine = liquidityEngine;

        emit LogSetLiquidityEngine(msg.sender, liquidityEngine);
    }

    /// @inheritdoc IGlobalConfigurationModule
    function configureCollateralPriority(address[] calldata collateralTypes) external override onlyOwner {
        if (collateralTypes.length == 0) {
            revert Errors.ZeroInput("collateralTypes");
        }

        GlobalConfiguration.Data storage globalConfiguration = GlobalConfiguration.load();
        globalConfiguration.configureCollateralPriority(collateralTypes);

        emit LogConfigureCollateralPriority(msg.sender, collateralTypes);
    }

    /// @inheritdoc IGlobalConfigurationModule
    function configureLiquidators(
        address[] calldata liquidators,
        bool[] calldata enable
    )
        external
        override
        onlyOwner
    {
        if (liquidators.length == 0) {
            revert Errors.ZeroInput("liquidators");
        }

        if (liquidators.length != enable.length) {
            revert Errors.ArrayLengthMismatch(liquidators.length, enable.length);
        }

        GlobalConfiguration.Data storage globalConfiguration = GlobalConfiguration.load();
        globalConfiguration.configureLiquidators(liquidators, enable);

        emit LogConfigureLiquidators(msg.sender, liquidators, enable);
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

            emit LogConfigureMarginCollateral(msg.sender, collateralType, depositCap, decimals, priceFeed);
        } catch {
            revert Errors.InvalidMarginCollateralConfiguration(collateralType, 0, priceFeed);
        }
    }

    /// @inheritdoc IGlobalConfigurationModule
    function removeCollateralFromPriorityList(address collateralType) external override onlyOwner {
        if (collateralType == address(0)) {
            revert Errors.ZeroInput("collateralType");
        }

        GlobalConfiguration.Data storage globalConfiguration = GlobalConfiguration.load();
        globalConfiguration.removeCollateralTypeFromPriorityList(collateralType);

        emit LogRemoveCollateralFromPriorityList(msg.sender, collateralType);
    }

    /// @inheritdoc IGlobalConfigurationModule
    function configureSystemParameters(
        uint128 maxPositionsPerAccount,
        uint128 marketOrderMaxLifetime,
        uint128 liquidationFeeUsdX18
    )
        external
        override
        onlyOwner
    {
        if (maxPositionsPerAccount == 0) {
            revert Errors.ZeroInput("maxPositionsPerAccount");
        }

        if (marketOrderMaxLifetime == 0) {
            revert Errors.ZeroInput("marketOrderMaxLifetime");
        }

        if (liquidationFeeUsdX18 == 0) {
            revert Errors.ZeroInput("liquidationFeeUsdX18");
        }

        GlobalConfiguration.Data storage globalConfiguration = GlobalConfiguration.load();

        globalConfiguration.maxPositionsPerAccount = maxPositionsPerAccount;
        globalConfiguration.marketOrderMaxLifetime = marketOrderMaxLifetime;
        globalConfiguration.liquidationFeeUsdX18 = liquidationFeeUsdX18;

        emit LogConfigureSystemParameters(
            msg.sender, maxPositionsPerAccount, marketOrderMaxLifetime, liquidationFeeUsdX18
        );
    }

    // TODO: add missing zero checks
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
        if (params.initialMarginRateX18 == 0) {
            revert Errors.ZeroInput("initialMarginRateX18");
        }

        GlobalConfiguration.Data storage globalConfiguration = GlobalConfiguration.load();

        PerpMarket.create(
            params.marketId,
            params.name,
            params.symbol,
            params.priceAdapter,
            params.initialMarginRateX18,
            params.maintenanceMarginRateX18,
            params.maxOpenInterest,
            params.maxFundingVelocity,
            params.skewScale,
            params.minTradeSizeX18,
            params.marketOrderConfiguration,
            params.customTriggerStrategies,
            params.orderFees
        );
        globalConfiguration.addMarket(params.marketId);

        emit LogCreatePerpMarket(msg.sender, params.marketId);
    }

    /// @inheritdoc IGlobalConfigurationModule
    function updatePerpMarketConfiguration(
        uint128 marketId,
        string calldata name,
        string calldata symbol,
        address priceAdapter,
        uint128 initialMarginRateX18,
        uint128 maintenanceMarginRateX18,
        uint128 maxOpenInterest,
        uint128 maxFundingVelocity,
        uint256 skewScale,
        uint256 minTradeSizeX18,
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
        if (initialMarginRateX18 == 0) {
            revert Errors.ZeroInput("initialMarginRateX18");
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
            initialMarginRateX18,
            maintenanceMarginRateX18,
            maxOpenInterest,
            maxFundingVelocity,
            skewScale,
            minTradeSizeX18,
            orderFees
        );

        emit LogConfigurePerpMarket(msg.sender, marketId);
    }

    /// @inheritdoc IGlobalConfigurationModule
    function updateSettlementConfiguration(
        uint128 marketId,
        uint128 settlementId,
        SettlementConfiguration.Data memory newSettlementConfiguration
    )
        external
        override
        onlyOwner
    {
        SettlementConfiguration.update(marketId, settlementId, newSettlementConfiguration);

        emit LogUpdateSettlementConfiguration(msg.sender, marketId, settlementId);
    }

    function updatePerpMarketStatus(uint128 marketId, bool enable) external override onlyOwner {
        GlobalConfiguration.Data storage globalConfiguration = GlobalConfiguration.load();
        PerpMarket.Data storage perpMarket = PerpMarket.load(marketId);

        if (!perpMarket.initialized) {
            revert Errors.PerpMarketNotInitialized(marketId);
        }

        if (enable) {
            globalConfiguration.addMarket(marketId);

            emit LogEnablePerpMarket(msg.sender, marketId);
        } else {
            globalConfiguration.removeMarket(marketId);

            emit LogDisablePerpMarket(msg.sender, marketId);
        }
    }
}
