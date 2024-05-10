// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { Base_Integration_Shared_Test } from "test/integration/shared/BaseIntegration.t.sol";
import { GlobalConfigurationBranch } from "@zaros/perpetuals/branches/GlobalConfigurationBranch.sol";
import { GlobalConfiguration } from "@zaros/perpetuals/leaves/GlobalConfiguration.sol";
import { OrderFees } from "@zaros/perpetuals/leaves/OrderFees.sol";
import { PerpMarket } from "@zaros/perpetuals/leaves/PerpMarket.sol";
import { SettlementConfiguration } from "@zaros/perpetuals/leaves/SettlementConfiguration.sol";

contract CreatePerpMarket_Integration_Test is Base_Integration_Shared_Test {
    function setUp() public override {
        Base_Integration_Shared_Test.setUp();
        changePrank({ msgSender: users.owner });
        configureSystemParameters();
    }

    function test_RevertGiven_MarketIdIsZero(uint256 marketId) external {
        SettlementConfiguration.Data[] memory customOrdersConfigurations;
        SettlementConfiguration.Data memory marketOrderConfiguration;

        GlobalConfigurationBranch.CreatePerpMarketParams memory params = GlobalConfigurationBranch
            .CreatePerpMarketParams({
            marketId: 0,
            name: "BTC/USD",
            symbol: "BTC",
            priceAdapter: address(0x20),
            initialMarginRateX18: 1,
            maintenanceMarginRateX18: 1,
            maxOpenInterest: 1,
            maxFundingVelocity: 1,
            skewScale: 1,
            minTradeSizeX18: 1,
            marketOrderConfiguration: marketOrderConfiguration,
            customOrderStrategies: customOrdersConfigurations,
            orderFees: OrderFees.Data({ makerFee: 0.0004e18, takerFee: 0.0008e18 })
        });

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "marketId") });

        changePrank({ msgSender: users.owner });
        perpsEngine.createPerpMarket(params);
    }

    modifier givenMarketIdIsNotZero() {
        _;
    }

    function test_RevertWhen_LengthOfNameIsZero() external givenMarketIdIsNotZero {
        SettlementConfiguration.Data[] memory customOrdersConfigurations;
        SettlementConfiguration.Data memory marketOrderConfiguration;

        GlobalConfigurationBranch.CreatePerpMarketParams memory params = GlobalConfigurationBranch
            .CreatePerpMarketParams({
            marketId: 1,
            name: "",
            symbol: "BTC",
            priceAdapter: address(0x20),
            initialMarginRateX18: 1,
            maintenanceMarginRateX18: 1,
            maxOpenInterest: 1,
            maxFundingVelocity: 1,
            skewScale: 1,
            minTradeSizeX18: 1,
            marketOrderConfiguration: marketOrderConfiguration,
            customOrderStrategies: customOrdersConfigurations,
            orderFees: OrderFees.Data({ makerFee: 0.0004e18, takerFee: 0.0008e18 })
        });

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "name") });

        changePrank({ msgSender: users.owner });
        perpsEngine.createPerpMarket(params);
    }

    modifier givenLengthOfNameIsNotZero() {
        _;
    }

    function test_RevertWhen_LengthOfSymbolIsZero() external givenMarketIdIsNotZero givenLengthOfNameIsNotZero {
        SettlementConfiguration.Data[] memory customOrdersConfigurations;
        SettlementConfiguration.Data memory marketOrderConfiguration;

        GlobalConfigurationBranch.CreatePerpMarketParams memory params = GlobalConfigurationBranch
            .CreatePerpMarketParams({
            marketId: 1,
            name: "BTC/USD",
            symbol: "",
            priceAdapter: address(0x20),
            initialMarginRateX18: 1,
            maintenanceMarginRateX18: 1,
            maxOpenInterest: 1,
            maxFundingVelocity: 1,
            skewScale: 1,
            minTradeSizeX18: 1,
            marketOrderConfiguration: marketOrderConfiguration,
            customOrderStrategies: customOrdersConfigurations,
            orderFees: OrderFees.Data({ makerFee: 0.0004e18, takerFee: 0.0008e18 })
        });

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "symbol") });

        changePrank({ msgSender: users.owner });
        perpsEngine.createPerpMarket(params);
    }

    modifier givenLengthOfSymbolIsNotZero() {
        _;
    }

    function test_RevertWhen_PriceAdapterIsZero()
        external
        givenMarketIdIsNotZero
        givenLengthOfNameIsNotZero
        givenLengthOfSymbolIsNotZero
    {
        SettlementConfiguration.Data[] memory customOrdersConfigurations;
        SettlementConfiguration.Data memory marketOrderConfiguration;

        GlobalConfigurationBranch.CreatePerpMarketParams memory params = GlobalConfigurationBranch
            .CreatePerpMarketParams({
            marketId: 1,
            name: "BTC/USD",
            symbol: "BTC",
            priceAdapter: address(0),
            initialMarginRateX18: 1,
            maintenanceMarginRateX18: 1,
            maxOpenInterest: 1,
            maxFundingVelocity: 1,
            skewScale: 1,
            minTradeSizeX18: 1,
            marketOrderConfiguration: marketOrderConfiguration,
            customOrderStrategies: customOrdersConfigurations,
            orderFees: OrderFees.Data({ makerFee: 0.0004e18, takerFee: 0.0008e18 })
        });

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "priceAdapter") });

        changePrank({ msgSender: users.owner });
        perpsEngine.createPerpMarket(params);
    }

    modifier givenPriceAdapterIsNotZero() {
        _;
    }

    function test_RevertWhen_MaintenanceMarginRateIsZero()
        external
        givenMarketIdIsNotZero
        givenLengthOfNameIsNotZero
        givenLengthOfSymbolIsNotZero
        givenPriceAdapterIsNotZero
    {
        SettlementConfiguration.Data[] memory customOrdersConfigurations;
        SettlementConfiguration.Data memory marketOrderConfiguration;

        GlobalConfigurationBranch.CreatePerpMarketParams memory params = GlobalConfigurationBranch
            .CreatePerpMarketParams({
            marketId: 1,
            name: "BTC/USD",
            symbol: "BTC",
            priceAdapter: address(0x20),
            initialMarginRateX18: 1,
            maintenanceMarginRateX18: 0,
            maxOpenInterest: 1,
            maxFundingVelocity: 1,
            skewScale: 1,
            minTradeSizeX18: 1,
            marketOrderConfiguration: marketOrderConfiguration,
            customOrderStrategies: customOrdersConfigurations,
            orderFees: OrderFees.Data({ makerFee: 0.0004e18, takerFee: 0.0008e18 })
        });

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "maintenanceMarginRateX18") });

        changePrank({ msgSender: users.owner });
        perpsEngine.createPerpMarket(params);
    }

    modifier givenMaintenanceMarginRateIsNotZero() {
        _;
    }

    function test_RevertWhen_MaxOpenInterestIsZero()
        external
        givenMarketIdIsNotZero
        givenLengthOfNameIsNotZero
        givenLengthOfSymbolIsNotZero
        givenPriceAdapterIsNotZero
        givenMaintenanceMarginRateIsNotZero
    {
        SettlementConfiguration.Data[] memory customOrdersConfigurations;
        SettlementConfiguration.Data memory marketOrderConfiguration;

        GlobalConfigurationBranch.CreatePerpMarketParams memory params = GlobalConfigurationBranch
            .CreatePerpMarketParams({
            marketId: 1,
            name: "BTC/USD",
            symbol: "BTC",
            priceAdapter: address(0x20),
            initialMarginRateX18: 1,
            maintenanceMarginRateX18: 1,
            maxOpenInterest: 0,
            maxFundingVelocity: 1,
            skewScale: 1,
            minTradeSizeX18: 1,
            marketOrderConfiguration: marketOrderConfiguration,
            customOrderStrategies: customOrdersConfigurations,
            orderFees: OrderFees.Data({ makerFee: 0.0004e18, takerFee: 0.0008e18 })
        });

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "maxOpenInterest") });

        changePrank({ msgSender: users.owner });
        perpsEngine.createPerpMarket(params);
    }

    modifier givenMaxOpenInterestIsNotZero() {
        _;
    }

    function test_RevertWhen_InitialMarginRateIsZero()
        external
        givenMarketIdIsNotZero
        givenLengthOfNameIsNotZero
        givenLengthOfSymbolIsNotZero
        givenPriceAdapterIsNotZero
        givenMaintenanceMarginRateIsNotZero
        givenMaxOpenInterestIsNotZero
    {
        SettlementConfiguration.Data[] memory customOrdersConfigurations;
        SettlementConfiguration.Data memory marketOrderConfiguration;

        GlobalConfigurationBranch.CreatePerpMarketParams memory params = GlobalConfigurationBranch
            .CreatePerpMarketParams({
            marketId: 1,
            name: "BTC/USD",
            symbol: "BTC",
            priceAdapter: address(0x20),
            initialMarginRateX18: 0,
            maintenanceMarginRateX18: 1,
            maxOpenInterest: 1,
            maxFundingVelocity: 1,
            skewScale: 1,
            minTradeSizeX18: 1,
            marketOrderConfiguration: marketOrderConfiguration,
            customOrderStrategies: customOrdersConfigurations,
            orderFees: OrderFees.Data({ makerFee: 0.0004e18, takerFee: 0.0008e18 })
        });

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "initialMarginRateX18") });

        changePrank({ msgSender: users.owner });
        perpsEngine.createPerpMarket(params);
    }

    modifier givenInitialMarginRateIsNotZero() {
        _;
    }

    function test_RevertWhen_SkewScaleIsZero()
        external
        givenMarketIdIsNotZero
        givenLengthOfNameIsNotZero
        givenLengthOfSymbolIsNotZero
        givenPriceAdapterIsNotZero
        givenMaintenanceMarginRateIsNotZero
        givenMaxOpenInterestIsNotZero
        givenInitialMarginRateIsNotZero
    {
        SettlementConfiguration.Data[] memory customOrdersConfigurations;
        SettlementConfiguration.Data memory marketOrderConfiguration;

        GlobalConfigurationBranch.CreatePerpMarketParams memory params = GlobalConfigurationBranch
            .CreatePerpMarketParams({
            marketId: 1,
            name: "BTC/USD",
            symbol: "BTC",
            priceAdapter: address(0x20),
            initialMarginRateX18: 1,
            maintenanceMarginRateX18: 1,
            maxOpenInterest: 1,
            maxFundingVelocity: 1,
            skewScale: 0,
            minTradeSizeX18: 1,
            marketOrderConfiguration: marketOrderConfiguration,
            customOrderStrategies: customOrdersConfigurations,
            orderFees: OrderFees.Data({ makerFee: 0.0004e18, takerFee: 0.0008e18 })
        });

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "skewScale") });

        changePrank({ msgSender: users.owner });
        perpsEngine.createPerpMarket(params);
    }

    modifier givenSkewScaleIsNotZero() {
        _;
    }

    function test_RevertWhen_MinTradeSizeIsZero()
        external
        givenMarketIdIsNotZero
        givenLengthOfNameIsNotZero
        givenLengthOfSymbolIsNotZero
        givenPriceAdapterIsNotZero
        givenMaintenanceMarginRateIsNotZero
        givenMaxOpenInterestIsNotZero
        givenInitialMarginRateIsNotZero
        givenSkewScaleIsNotZero
    {
        SettlementConfiguration.Data[] memory customOrdersConfigurations;
        SettlementConfiguration.Data memory marketOrderConfiguration;

        GlobalConfigurationBranch.CreatePerpMarketParams memory params = GlobalConfigurationBranch
            .CreatePerpMarketParams({
            marketId: 1,
            name: "BTC/USD",
            symbol: "BTC",
            priceAdapter: address(0x20),
            initialMarginRateX18: 1,
            maintenanceMarginRateX18: 1,
            maxOpenInterest: 1,
            maxFundingVelocity: 1,
            skewScale: 1,
            minTradeSizeX18: 0,
            marketOrderConfiguration: marketOrderConfiguration,
            customOrderStrategies: customOrdersConfigurations,
            orderFees: OrderFees.Data({ makerFee: 0.0004e18, takerFee: 0.0008e18 })
        });

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "minTradeSizeX18") });

        changePrank({ msgSender: users.owner });
        perpsEngine.createPerpMarket(params);
    }

    function test_GivenMinTradeSizeIsNotZero(uint256 marketId)
        external
        givenMarketIdIsNotZero
        givenLengthOfNameIsNotZero
        givenLengthOfSymbolIsNotZero
        givenPriceAdapterIsNotZero
        givenMaintenanceMarginRateIsNotZero
        givenMaxOpenInterestIsNotZero
        givenInitialMarginRateIsNotZero
        givenSkewScaleIsNotZero
    {
        changePrank({ msgSender: users.owner });

        SettlementConfiguration.Data[] memory customOrdersConfigurations;
        SettlementConfiguration.Data memory marketOrderConfiguration;

        GlobalConfigurationBranch.CreatePerpMarketParams memory params = GlobalConfigurationBranch
            .CreatePerpMarketParams({
            marketId: 1,
            name: "BTC/USD",
            symbol: "BTC",
            priceAdapter: address(0x20),
            initialMarginRateX18: 1,
            maintenanceMarginRateX18: 1,
            maxOpenInterest: 1,
            maxFundingVelocity: 1,
            skewScale: 1,
            minTradeSizeX18: 1,
            marketOrderConfiguration: marketOrderConfiguration,
            customOrderStrategies: customOrdersConfigurations,
            orderFees: OrderFees.Data({ makerFee: 0.0004e18, takerFee: 0.0008e18 })
        });

        // it should emit {LogCreatePerpMarket} event
        vm.expectEmit({ emitter: address(perpsEngine) });
        emit GlobalConfigurationBranch.LogCreatePerpMarket(users.owner, params.marketId);

        // it should create perp market
        // it should enable perp market
        perpsEngine.createPerpMarket({ params: params });
    }
}
