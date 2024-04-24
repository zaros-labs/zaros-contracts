// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { Constants } from "@zaros/utils/Constants.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { IGlobalConfigurationBranch } from "../interfaces/IGlobalConfigurationBranch.sol";
import { GlobalConfiguration } from "../leaves/GlobalConfiguration.sol";
import { PerpMarket } from "../leaves/PerpMarket.sol";
import { MarginCollateralConfiguration } from "../leaves/MarginCollateralConfiguration.sol";
import { MarketConfiguration } from "../leaves/MarketConfiguration.sol";
import { OrderFees } from "../leaves/OrderFees.sol";
import { SettlementConfiguration } from "../leaves/SettlementConfiguration.sol";

// OpenZeppelin Upgradeable dependencies
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";
import { ERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";
import { Initializable } from "@openzeppelin-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/access/OwnableUpgradeable.sol";

// PRB Math dependencies
import { UD60x18, ud60x18, UNIT as UD_UNIT } from "@prb-math/UD60x18.sol";

/// @notice See {IGlobalConfigurationBranch}.
contract GlobalConfigurationBranch is IGlobalConfigurationBranch, Initializable, OwnableUpgradeable {
    using EnumerableSet for EnumerableSet.UintSet;
    using GlobalConfiguration for GlobalConfiguration.Data;
    using PerpMarket for PerpMarket.Data;
    using MarginCollateralConfiguration for MarginCollateralConfiguration.Data;
    using MarketConfiguration for MarketConfiguration.Data;

    constructor() {
        _disableInitializers();
    }

    /// TODO: Create inheritable AuthBranch
    /// @dev The Ownable contract is initialized at the UpgradeBranch.
    /// @dev {GlobalConfigurationBranch} UUPS initializer.
    function initialize(address perpsAccountToken, address usdToken) external initializer {
        GlobalConfiguration.Data storage globalConfiguration = GlobalConfiguration.load();
        globalConfiguration.perpsAccountToken = perpsAccountToken;
        globalConfiguration.usdToken = usdToken;
    }

    /// @inheritdoc IGlobalConfigurationBranch
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

    /// @inheritdoc IGlobalConfigurationBranch
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

    /// @inheritdoc IGlobalConfigurationBranch
    function setPerpsAccountToken(address perpsAccountToken) external {
        if (perpsAccountToken == address(0)) {
            revert Errors.PerpsAccountTokenNotDefined();
        }

        GlobalConfiguration.Data storage globalConfiguration = GlobalConfiguration.load();
        globalConfiguration.perpsAccountToken = perpsAccountToken;

        emit LogSetPerpsAccountToken(msg.sender, perpsAccountToken);
    }

    /// @inheritdoc IGlobalConfigurationBranch
    function configureCollateralPriority(address[] calldata collateralTypes) external override onlyOwner {
        if (collateralTypes.length == 0) {
            revert Errors.ZeroInput("collateralTypes");
        }

        GlobalConfiguration.Data storage globalConfiguration = GlobalConfiguration.load();
        globalConfiguration.configureCollateralPriority(collateralTypes);

        emit LogConfigureCollateralPriority(msg.sender, collateralTypes);
    }

    /// @inheritdoc IGlobalConfigurationBranch
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

    /// @inheritdoc IGlobalConfigurationBranch
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

    /// @inheritdoc IGlobalConfigurationBranch
    function removeCollateralFromPriorityList(address collateralType) external override onlyOwner {
        if (collateralType == address(0)) {
            revert Errors.ZeroInput("collateralType");
        }

        GlobalConfiguration.Data storage globalConfiguration = GlobalConfiguration.load();
        globalConfiguration.removeCollateralTypeFromPriorityList(collateralType);

        emit LogRemoveCollateralFromPriorityList(msg.sender, collateralType);
    }

    /// @inheritdoc IGlobalConfigurationBranch
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
    /// @inheritdoc IGlobalConfigurationBranch
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
            PerpMarket.CreateParams({
                marketId: params.marketId,
                name: params.name,
                symbol: params.symbol,
                priceAdapter: params.priceAdapter,
                initialMarginRateX18: params.initialMarginRateX18,
                maintenanceMarginRateX18: params.maintenanceMarginRateX18,
                maxOpenInterest: params.maxOpenInterest,
                maxFundingVelocity: params.maxFundingVelocity,
                skewScale: params.skewScale,
                minTradeSizeX18: params.minTradeSizeX18,
                marketOrderConfiguration: params.marketOrderConfiguration,
                customOrderStrategies: params.customOrderStrategies,
                orderFees: params.orderFees
            })
        );
        globalConfiguration.addMarket(params.marketId);

        emit LogCreatePerpMarket(msg.sender, params.marketId);
    }

    /// @inheritdoc IGlobalConfigurationBranch
    function updatePerpMarketConfiguration(UpdatePerpMarketConfigurationParams calldata params)
        external
        override
        onlyOwner
    {
        PerpMarket.Data storage perpMarket = PerpMarket.load(params.marketId);
        MarketConfiguration.Data storage perpMarketConfiguration = perpMarket.configuration;

        if (!perpMarket.initialized) {
            revert Errors.PerpMarketNotInitialized(params.marketId);
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
        if (params.initialMarginRateX18 == 0) {
            revert Errors.ZeroInput("initialMarginRateX18");
        }

        if (params.maintenanceMarginRateX18 == 0) {
            revert Errors.ZeroInput("maintenanceMarginRateX18");
        }
        if (params.skewScale == 0) {
            revert Errors.ZeroInput("skewScale");
        }
        if (params.minTradeSizeX18 == 0) {
            revert Errors.ZeroInput("minTradeSizeX18");
        }

        perpMarketConfiguration.update(
            params.name,
            params.symbol,
            params.priceAdapter,
            params.initialMarginRateX18,
            params.maintenanceMarginRateX18,
            params.maxOpenInterest,
            params.maxFundingVelocity,
            params.skewScale,
            params.minTradeSizeX18,
            params.orderFees
        );

        emit LogConfigurePerpMarket(msg.sender, params.marketId);
    }

    /// @inheritdoc IGlobalConfigurationBranch
    function updateSettlementConfiguration(
        uint128 marketId,
        uint128 settlementConfigurationId,
        SettlementConfiguration.Data memory newSettlementConfiguration
    )
        external
        override
        onlyOwner
    {
        SettlementConfiguration.update(marketId, settlementConfigurationId, newSettlementConfiguration);

        emit LogUpdateSettlementConfiguration(msg.sender, marketId, settlementConfigurationId);
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
