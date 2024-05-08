// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.25;

// Zaros dependencies
import { Constants } from "@zaros/utils/Constants.sol";
import { Errors } from "@zaros/utils/Errors.sol";
// import { IGlobalConfigurationBranch } from "../interfaces/IGlobalConfigurationBranch.sol";
import { GlobalConfiguration } from "../leaves/GlobalConfiguration.sol";
import { PerpMarket } from "../leaves/PerpMarket.sol";
import { MarginCollateralConfiguration } from "../leaves/MarginCollateralConfiguration.sol";
import { MarketConfiguration } from "../leaves/MarketConfiguration.sol";
import { SettlementConfiguration } from "../leaves/SettlementConfiguration.sol";
import { OrderFees } from "../leaves/OrderFees.sol";


// OpenZeppelin Upgradeable dependencies
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";
import { ERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";
import { Initializable } from "@openzeppelin-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/access/OwnableUpgradeable.sol";

/// @title Global Configuration Branch.
/// @notice This  is used by the protocol controller to configure the perps
/// exchange system.
contract GlobalConfigurationBranch is Initializable, OwnableUpgradeable {
    using EnumerableSet for EnumerableSet.UintSet;
    using GlobalConfiguration for GlobalConfiguration.Data;
    using PerpMarket for PerpMarket.Data;
    using MarginCollateralConfiguration for MarginCollateralConfiguration.Data;
    using MarketConfiguration for MarketConfiguration.Data;

    constructor() {
        _disableInitializers();
    }

    /// @notice Emitted when the account token address is set.
    event LogSetTradingAccountToken(address indexed sender, address indexed tradingAccountToken);

    /// @notice Emitted when the collateral priority is configured.
    /// @param sender The address that configured the collateral priority.
    /// @param collateralTypes The array of collateral type addresses, ordered by priority.
    event LogConfigureCollateralLiquidationPriority(address indexed sender, address[] collateralTypes);

    /// @notice Emitted when the liquidators are configured.
    /// @param sender The address that configured the liquidators.
    /// @param liquidators The array of liquidator addresses.
    /// @param enable The array of boolean values that enable or disable the liquidator.
    event LogConfigureLiquidators(address indexed sender, address[] liquidators, bool[] enable);

    /// @notice Emitted when a new collateral type is enabled or disabled.
    /// @param sender The address that enabled or disabled the collateral type.
    /// @param collateralType The address of the collateral type.
    /// @param depositCap The maximum amount of collateral that can be deposited.
    /// @param decimals The amount of decimals of the collateral type's ERC20 token.
    /// @param priceFeed The price oracle address.
    event LogConfigureMarginCollateral(
        address indexed sender, address indexed collateralType, uint128 depositCap, uint8 decimals, address priceFeed
    );

    /// @notice Emitted when a collateral type is removed from the collateral priority.
    /// @param sender The address that removed the collateral type from the priority list.
    /// @param collateralType The address of the collateral type.
    event LogRemoveCollateralFromLiquidationPriority(address indexed sender, address indexed collateralType);

    /// @notice Emitted when the global system parameters are configured.
    /// @param sender The address that configured the system parameters.
    /// @param maxPositionsPerAccount The maximum number of open positions per account.
    /// @param marketOrderMaxLifetime The maximum lifetime of a market order to be considered active.
    /// @param liquidationFeeUsdX18 The liquidation fee in USD.
    event LogConfigureSystemParameters(
        address indexed sender,
        uint128 maxPositionsPerAccount,
        uint128 marketOrderMaxLifetime,
        uint128 liquidationFeeUsdX18
    );

    /// @notice Emitted when a new perps market is created.
    /// @param sender The address that configured the price feed.
    /// @param marketId The perps market id.
    event LogCreatePerpMarket(address indexed sender, uint128 marketId);

    /// @notice Emitted when a perps market is reconfigured.
    /// @param sender The address that configured the perps market.
    /// @param marketId The perps market id.
    event LogUpdatePerpMarketConfiguration(address indexed sender, uint128 marketId);

    /// @notice Emitted when the settlement configuration of a given market is updated.
    /// @param sender The address that updated the settlement configuration.
    /// @param marketId The perps market id.
    /// @param settlementConfigurationId The perps market settlement configuration id.
    event LogUpdateSettlementConfiguration(
        address indexed sender, uint128 indexed marketId, uint128 settlementConfigurationId
    );

    /// @notice Emitted when a perp market is re-enabled by the owner.
    /// @param marketId The perps market id.
    event LogEnablePerpMarket(address indexed sender, uint128 marketId);

    /// @notice Emitted when a perp market is disabled by the owner.
    /// @param marketId The perps market id.
    event LogDisablePerpMarket(address indexed sender, uint128 marketId);

    /// @dev The Ownable contract is initialized at the UpgradeBranch.
    /// @dev {GlobalConfigurationBranch} UUPS initializer.
    function initialize(address tradingAccountToken, address usdToken) external initializer {
        GlobalConfiguration.Data storage globalConfiguration = GlobalConfiguration.load();
        globalConfiguration.tradingAccountToken = tradingAccountToken;
        globalConfiguration.usdToken = usdToken;
    }

    function getAccountsWithActivePositions(
        uint256 lowerBound,
        uint256 upperBound
    )
        external
        view

        returns (uint128[] memory accountsIds)
    {
        GlobalConfiguration.Data storage globalConfiguration = GlobalConfiguration.load();

        for (uint256 i = lowerBound; i < upperBound; i++) {
            accountsIds[i] = uint128(globalConfiguration.accountsIdsWithActivePositions.at(i));
        }
    }

    /// @dev Returns the maximum amount that can be deposited as margin for a given
    /// collateral type.
    /// @param collateralType The address of the collateral type.
    /// @return marginCollateralConfiguration The configuration parameters of the given collateral type.
    function getMarginCollateralConfiguration(address collateralType)
        external
        pure

        returns (MarginCollateralConfiguration.Data memory)
    {
        MarginCollateralConfiguration.Data memory marginCollateralConfiguration =
            MarginCollateralConfiguration.load(collateralType);

        return marginCollateralConfiguration;
    }

    /// @notice Sets the address of the account token NFT contract.
    /// @param tradingAccountToken The account token address.
    function setTradingAccountToken(address tradingAccountToken) external {
        if (tradingAccountToken == address(0)) {
            revert Errors.TradingAccountTokenNotDefined();
        }

        GlobalConfiguration.Data storage globalConfiguration = GlobalConfiguration.load();
        globalConfiguration.tradingAccountToken = tradingAccountToken;

        emit LogSetTradingAccountToken(msg.sender, tradingAccountToken);
    }

    /// @notice Configures the collateral priority.
    /// @param collateralTypes The array of collateral type addresses.
    function configureCollateralLiquidationPriority(address[] calldata collateralTypes) external  onlyOwner {
        if (collateralTypes.length == 0) {
            revert Errors.ZeroInput("collateralTypes");
        }

        GlobalConfiguration.Data storage globalConfiguration = GlobalConfiguration.load();
        globalConfiguration.configureCollateralLiquidationPriority(collateralTypes);

        emit LogConfigureCollateralLiquidationPriority(msg.sender, collateralTypes);
    }

    /// @notice Configures the liquidators.
    /// @param liquidators The array of liquidator addresses.
    /// @param enable The array of boolean values that enable or disable the liquidator.
    function configureLiquidators(
        address[] calldata liquidators,
        bool[] calldata enable
    )
        external

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

    /// @notice Configures the settings of a given margin collateral type.
    /// @param collateralType The address of the collateral type.
    /// @param depositCap The maximum amount of collateral that can be deposited.
    /// @param loanToValue The value used to calculate the effective margin balance of a given collateral type.
    /// @param priceFeed The price oracle address.
    function configureMarginCollateral(
        address collateralType,
        uint128 depositCap,
        uint120 loanToValue,
        address priceFeed
    )
        external

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

    /// @notice Removes the given collateral type from the collateral priority.
    /// @param collateralType The address of the collateral type to remove.
    function removeCollateralFromLiquidationPriority(address collateralType) external  onlyOwner {
        if (collateralType == address(0)) {
            revert Errors.ZeroInput("collateralType");
        }

        GlobalConfiguration.Data storage globalConfiguration = GlobalConfiguration.load();
        globalConfiguration.removeCollateralFromLiquidationPriority(collateralType);

        emit LogRemoveCollateralFromLiquidationPriority(msg.sender, collateralType);
    }

    /// @notice Configures the system parameters.
    /// @param maxPositionsPerAccount The maximum number of open positions per account.
    /// @param marketOrderMaxLifetime The maximum lifetime of a market order to be considered active.
    /// @param liquidationFeeUsdX18 The liquidation fee in USD.
    function configureSystemParameters(
        uint128 maxPositionsPerAccount,
        uint128 marketOrderMaxLifetime,
        uint128 liquidationFeeUsdX18
    )
        external

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

    /// @notice `createPerpMarket` function parameters.
    /// @param marketId The perps market id.
    /// @param name The perps market name.
    /// @param symbol The perps market symbol.
    /// @param priceAdapter The price adapter contract, which handles the market's index price.
    /// @param initialMarginRateX18 The perps market min initial margin rate, which defines the max leverage.
    /// @param maintenanceMarginRateX18 The perps market maintenance margin rate.
    /// @param maxOpenInterest The perps market maximum open interest per side.
    /// @param maxFundingVelocity The perps market maximum funding rate velocity.
    /// @param skewScale The configuration parameter used to scale the market's price impact and funding rate.
    /// @param minTradeSizeX18 The minimum size of a trade in contract units.
    /// @param marketOrderConfiguration The perps market settlement configuration.
    /// @param orderFees The perps market maker and taker fees.
    struct CreatePerpMarketParams {
        uint128 marketId;
        string name;
        string symbol;
        address priceAdapter;
        uint128 initialMarginRateX18;
        uint128 maintenanceMarginRateX18;
        uint128 maxOpenInterest;
        uint128 maxFundingVelocity;
        uint256 skewScale;
        uint256 minTradeSizeX18;
        SettlementConfiguration.Data marketOrderConfiguration;
        SettlementConfiguration.Data[] customOrderStrategies;
        OrderFees.Data orderFees;
    }

    /// @notice Creates a new market with the requested market id.
    /// @dev See {CreatePerpMarketParams}.
    function createPerpMarket(CreatePerpMarketParams calldata params) external  onlyOwner {
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
        if (params.maintenanceMarginRateX18 == 0) {
            revert Errors.ZeroInput("maintenanceMarginRateX18");
        }
        if (params.skewScale == 0) {
            revert Errors.ZeroInput("skewScale");
        }
        if (params.minTradeSizeX18 == 0) {
            revert Errors.ZeroInput("minTradeSizeX18");
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

    /// @notice `updatePerpMarketConfiguration` params.
    /// @param marketId The perp market id.
    /// @param name The perp market name.
    /// @param symbol The perp market symbol.
    /// @param priceAdapter The price adapter contract, which handles the market's index price.
    /// @param initialMarginRateX18 The perp market min initial margin rate, which defines the max leverage.
    /// @param maintenanceMarginRateX18 The perp market maintenance margin rate.
    /// @param maxOpenInterest The perp market maximum open interest per side.
    /// @param maxFundingVelocity The perp market maximum funding rate velocity.
    /// @param skewScale The configuration parameter used to scale the market's price impact and funding rate.
    /// @param minTradeSizeX18 The minimum size of a trade in contract units.
    /// @param orderFees The perp market maker and taker fees.
    struct UpdatePerpMarketConfigurationParams {
        uint128 marketId;
        string name;
        string symbol;
        address priceAdapter;
        uint128 initialMarginRateX18;
        uint128 maintenanceMarginRateX18;
        uint128 maxOpenInterest;
        uint128 maxFundingVelocity;
        uint256 skewScale;
        uint256 minTradeSizeX18;
        OrderFees.Data orderFees;
    }

    /// @notice Updates the configuration variables of the given perp market id.
    /// @dev A market's configuration must be updated with caution, as the update of some variables may directly
    /// impact open positions.
    /// @dev See {UpdatePerpMarketConfigurationParams}.
    function updatePerpMarketConfiguration(UpdatePerpMarketConfigurationParams calldata params)
        external

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

        emit LogUpdatePerpMarketConfiguration(msg.sender, params.marketId);
    }

    /// @notice Updates the settlement configuration of a given market.
    /// @param marketId The perp market id.
    /// @param settlementConfigurationId The perp market settlement configuration id.
    /// @param newSettlementConfiguration The new settlement configuration.
    function updateSettlementConfiguration(
        uint128 marketId,
        uint128 settlementConfigurationId,
        SettlementConfiguration.Data memory newSettlementConfiguration
    )
        external

        onlyOwner
    {
        SettlementConfiguration.update(marketId, settlementConfigurationId, newSettlementConfiguration);

        emit LogUpdateSettlementConfiguration(msg.sender, marketId, settlementConfigurationId);
    }

    /// @notice Enables or disabled the perp market of the given market id.
    /// @param marketId The perps market id.
    /// @param enable Whether the market should be enabled or disabled.
    function updatePerpMarketStatus(uint128 marketId, bool enable) external  onlyOwner {
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
