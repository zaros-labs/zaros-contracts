// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { Base_Integration_Shared_Test } from "test/integration/shared/BaseIntegration.t.sol";
import { IGlobalConfigurationBranch } from "@zaros/perpetuals/interfaces/IGlobalConfigurationBranch.sol";
import { GlobalConfiguration } from "@zaros/perpetuals/leaves/GlobalConfiguration.sol";
import { OrderFees } from "@zaros/perpetuals/leaves/OrderFees.sol";
import { PerpMarket } from "@zaros/perpetuals/leaves/PerpMarket.sol";
import { SettlementConfiguration } from "@zaros/perpetuals/leaves/SettlementConfiguration.sol";

import "forge-std/console.sol";

contract UpdatePerpMarketConfiguration_Integration_Test is Base_Integration_Shared_Test{
    function setUp() public override {
        Base_Integration_Shared_Test.setUp();
        changePrank({ msgSender: users.owner });
        configureSystemParameters();
        createPerpMarkets();
        changePrank({ msgSender: users.naruto });
    }

    function test_RevertGiven_MarketIsNotInitialized(uint256 marketId) external {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        uint128 marketIdNotInitialized = uint128(FINAL_MARKET_ID) + 1;

        IGlobalConfigurationBranch.UpdatePerpMarketConfigurationParams memory params = IGlobalConfigurationBranch
            .UpdatePerpMarketConfigurationParams({
            marketId: marketIdNotInitialized,
            name: fuzzMarketConfig.marketName,
            symbol: fuzzMarketConfig.marketSymbol,
            priceAdapter: fuzzMarketConfig.priceAdapter,
            initialMarginRateX18: fuzzMarketConfig.imr,
            maintenanceMarginRateX18: fuzzMarketConfig.mmr,
            maxOpenInterest: fuzzMarketConfig.maxOi,
            maxFundingVelocity: fuzzMarketConfig.maxFundingVelocity,
            skewScale: fuzzMarketConfig.skewScale,
            minTradeSizeX18: fuzzMarketConfig.minTradeSize,
            orderFees: OrderFees.Data({ makerFee: 0.0004e18, takerFee: 0.0008e18 })
        });

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.PerpMarketNotInitialized.selector, marketIdNotInitialized) });

        changePrank({ msgSender: users.owner });
        perpsEngine.updatePerpMarketConfiguration(params);
    }

    modifier givenMarketIsInitialized() {
        _;
    }

    function test_RevertWhen_LengthOfNameIsZero(uint256 marketId) external givenMarketIsInitialized {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        IGlobalConfigurationBranch.UpdatePerpMarketConfigurationParams memory params = IGlobalConfigurationBranch
            .UpdatePerpMarketConfigurationParams({
            marketId: fuzzMarketConfig.marketId,
            name: "",
            symbol: fuzzMarketConfig.marketSymbol,
            priceAdapter: fuzzMarketConfig.priceAdapter,
            initialMarginRateX18: fuzzMarketConfig.imr,
            maintenanceMarginRateX18: fuzzMarketConfig.mmr,
            maxOpenInterest: fuzzMarketConfig.maxOi,
            maxFundingVelocity: fuzzMarketConfig.maxFundingVelocity,
            skewScale: fuzzMarketConfig.skewScale,
            minTradeSizeX18: fuzzMarketConfig.minTradeSize,
            orderFees: OrderFees.Data({ makerFee: 0.0004e18, takerFee: 0.0008e18 })
        });

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "name") });

        changePrank({ msgSender: users.owner });
        perpsEngine.updatePerpMarketConfiguration(params);
    }

    modifier givenLengthOfNameIsNotZero() {
        _;
    }

    function test_RevertWhen_LengthOfSymbolIsZero(uint256 marketId) external givenMarketIsInitialized givenLengthOfNameIsNotZero {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        IGlobalConfigurationBranch.UpdatePerpMarketConfigurationParams memory params = IGlobalConfigurationBranch
            .UpdatePerpMarketConfigurationParams({
            marketId: fuzzMarketConfig.marketId,
            name: fuzzMarketConfig.marketName,
            symbol: "",
            priceAdapter: fuzzMarketConfig.priceAdapter,
            initialMarginRateX18: fuzzMarketConfig.imr,
            maintenanceMarginRateX18: fuzzMarketConfig.mmr,
            maxOpenInterest: fuzzMarketConfig.maxOi,
            maxFundingVelocity: fuzzMarketConfig.maxFundingVelocity,
            skewScale: fuzzMarketConfig.skewScale,
            minTradeSizeX18: fuzzMarketConfig.minTradeSize,
            orderFees: OrderFees.Data({ makerFee: 0.0004e18, takerFee: 0.0008e18 })
        });

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "symbol") });

        changePrank({ msgSender: users.owner });
        perpsEngine.updatePerpMarketConfiguration(params);
    }

    modifier givenLengthOfSymbolIsNotZero() {
        _;
    }

    function test_RevertWhen_PriceAdapterIsZero(uint256 marketId)
        external
        givenMarketIsInitialized
        givenLengthOfNameIsNotZero
        givenLengthOfSymbolIsNotZero
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        IGlobalConfigurationBranch.UpdatePerpMarketConfigurationParams memory params = IGlobalConfigurationBranch
            .UpdatePerpMarketConfigurationParams({
            marketId: fuzzMarketConfig.marketId,
            name: fuzzMarketConfig.marketName,
            symbol: fuzzMarketConfig.marketSymbol,
            priceAdapter: address(0),
            initialMarginRateX18: fuzzMarketConfig.imr,
            maintenanceMarginRateX18: fuzzMarketConfig.mmr,
            maxOpenInterest: fuzzMarketConfig.maxOi,
            maxFundingVelocity: fuzzMarketConfig.maxFundingVelocity,
            skewScale: fuzzMarketConfig.skewScale,
            minTradeSizeX18: fuzzMarketConfig.minTradeSize,
            orderFees: OrderFees.Data({ makerFee: 0.0004e18, takerFee: 0.0008e18 })
        });

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "priceAdapter") });

        changePrank({ msgSender: users.owner });
        perpsEngine.updatePerpMarketConfiguration(params);
    }

    modifier givenPriceAdapterIsNotZero() {
        _;
    }

    function test_RevertWhen_MaintenanceMarginRateIsZero(uint256 marketId)
        external
        givenMarketIsInitialized
        givenLengthOfNameIsNotZero
        givenLengthOfSymbolIsNotZero
        givenPriceAdapterIsNotZero
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        IGlobalConfigurationBranch.UpdatePerpMarketConfigurationParams memory params = IGlobalConfigurationBranch
            .UpdatePerpMarketConfigurationParams({
            marketId: fuzzMarketConfig.marketId,
            name: fuzzMarketConfig.marketName,
            symbol: fuzzMarketConfig.marketSymbol,
            priceAdapter: fuzzMarketConfig.priceAdapter,
            initialMarginRateX18: fuzzMarketConfig.imr,
            maintenanceMarginRateX18: 0,
            maxOpenInterest: fuzzMarketConfig.maxOi,
            maxFundingVelocity: fuzzMarketConfig.maxFundingVelocity,
            skewScale: fuzzMarketConfig.skewScale,
            minTradeSizeX18: fuzzMarketConfig.minTradeSize,
            orderFees: OrderFees.Data({ makerFee: 0.0004e18, takerFee: 0.0008e18 })
        });

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "maintenanceMarginRateX18") });

        changePrank({ msgSender: users.owner });
        perpsEngine.updatePerpMarketConfiguration(params);
    }

    modifier givenMaintenanceMarginRateIsNotZero() {
        _;
    }

    function test_RevertWhen_MaxOpenInterestIsZero(uint256 marketId)
        external
        givenMarketIsInitialized
        givenLengthOfNameIsNotZero
        givenLengthOfSymbolIsNotZero
        givenPriceAdapterIsNotZero
        givenMaintenanceMarginRateIsNotZero
    {
        // MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        // IGlobalConfigurationBranch.UpdatePerpMarketConfigurationParams memory params = IGlobalConfigurationBranch
        //     .UpdatePerpMarketConfigurationParams({
        //     marketId: fuzzMarketConfig.marketId,
        //     name: fuzzMarketConfig.marketName,
        //     symbol: fuzzMarketConfig.marketSymbol,
        //     priceAdapter: fuzzMarketConfig.priceAdapter,
        //     initialMarginRateX18: fuzzMarketConfig.imr,
        //     maintenanceMarginRateX18: fuzzMarketConfig.mmr,
        //     maxOpenInterest: 0,
        //     maxFundingVelocity: fuzzMarketConfig.maxFundingVelocity,
        //     skewScale: fuzzMarketConfig.skewScale,
        //     minTradeSizeX18: fuzzMarketConfig.minTradeSize,
        //     orderFees: OrderFees.Data({ makerFee: 0.0004e18, takerFee: 0.0008e18 })
        // });

        // // it should revert
        // vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "maintenanceMarginRateX18") });

        // changePrank({ msgSender: users.owner });
        // perpsEngine.updatePerpMarketConfiguration(params);
    }

    modifier givenMaxOpenInterestIsNotZero() {
        _;
    }

    function test_RevertWhen_InitialMarginRateIsZero(uint256 marketId)
        external
        givenMarketIsInitialized
        givenLengthOfNameIsNotZero
        givenLengthOfSymbolIsNotZero
        givenPriceAdapterIsNotZero
        givenMaintenanceMarginRateIsNotZero
        givenMaxOpenInterestIsNotZero
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        IGlobalConfigurationBranch.UpdatePerpMarketConfigurationParams memory params = IGlobalConfigurationBranch
            .UpdatePerpMarketConfigurationParams({
            marketId: fuzzMarketConfig.marketId,
            name: fuzzMarketConfig.marketName,
            symbol: fuzzMarketConfig.marketSymbol,
            priceAdapter: fuzzMarketConfig.priceAdapter,
            initialMarginRateX18: 0,
            maintenanceMarginRateX18: fuzzMarketConfig.mmr,
            maxOpenInterest: fuzzMarketConfig.maxOi,
            maxFundingVelocity: fuzzMarketConfig.maxFundingVelocity,
            skewScale: fuzzMarketConfig.skewScale,
            minTradeSizeX18: fuzzMarketConfig.minTradeSize,
            orderFees: OrderFees.Data({ makerFee: 0.0004e18, takerFee: 0.0008e18 })
        });

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "initialMarginRateX18") });

        changePrank({ msgSender: users.owner });
        perpsEngine.updatePerpMarketConfiguration(params);
    }

    modifier givenInitialMarginRateIsNotZero() {
        _;
    }

    function test_RevertWhen_SkewScaleIsZero(uint256 marketId)
        external
        givenMarketIsInitialized
        givenLengthOfNameIsNotZero
        givenLengthOfSymbolIsNotZero
        givenPriceAdapterIsNotZero
        givenMaintenanceMarginRateIsNotZero
        givenMaxOpenInterestIsNotZero
        givenInitialMarginRateIsNotZero
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        IGlobalConfigurationBranch.UpdatePerpMarketConfigurationParams memory params = IGlobalConfigurationBranch
            .UpdatePerpMarketConfigurationParams({
            marketId: fuzzMarketConfig.marketId,
            name: fuzzMarketConfig.marketName,
            symbol: fuzzMarketConfig.marketSymbol,
            priceAdapter: fuzzMarketConfig.priceAdapter,
            initialMarginRateX18: fuzzMarketConfig.imr,
            maintenanceMarginRateX18: fuzzMarketConfig.mmr,
            maxOpenInterest: fuzzMarketConfig.maxOi,
            maxFundingVelocity: fuzzMarketConfig.maxFundingVelocity,
            skewScale: 0,
            minTradeSizeX18: fuzzMarketConfig.minTradeSize,
            orderFees: OrderFees.Data({ makerFee: 0.0004e18, takerFee: 0.0008e18 })
        });

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "skewScale") });

        changePrank({ msgSender: users.owner });
        perpsEngine.updatePerpMarketConfiguration(params);
    }

    modifier givenSkewScaleIsNotZero() {
        _;
    }

    function test_RevertWhen_MinTradeSizeIsZero(uint256 marketId)
        external
        givenMarketIsInitialized
        givenLengthOfNameIsNotZero
        givenLengthOfSymbolIsNotZero
        givenPriceAdapterIsNotZero
        givenMaintenanceMarginRateIsNotZero
        givenMaxOpenInterestIsNotZero
        givenInitialMarginRateIsNotZero
        givenSkewScaleIsNotZero
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        IGlobalConfigurationBranch.UpdatePerpMarketConfigurationParams memory params = IGlobalConfigurationBranch
            .UpdatePerpMarketConfigurationParams({
            marketId: fuzzMarketConfig.marketId,
            name: fuzzMarketConfig.marketName,
            symbol: fuzzMarketConfig.marketSymbol,
            priceAdapter: fuzzMarketConfig.priceAdapter,
            initialMarginRateX18: fuzzMarketConfig.imr,
            maintenanceMarginRateX18: fuzzMarketConfig.mmr,
            maxOpenInterest: fuzzMarketConfig.maxOi,
            maxFundingVelocity: fuzzMarketConfig.maxFundingVelocity,
            skewScale: fuzzMarketConfig.skewScale,
            minTradeSizeX18: 0,
            orderFees: OrderFees.Data({ makerFee: 0.0004e18, takerFee: 0.0008e18 })
        });

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "minTradeSizeX18") });

        changePrank({ msgSender: users.owner });
        perpsEngine.updatePerpMarketConfiguration(params);
    }

    function test_GivenMinTradeSizeIsNotZero(uint256 marketId)
        external
        givenMarketIsInitialized
        givenLengthOfNameIsNotZero
        givenLengthOfSymbolIsNotZero
        givenPriceAdapterIsNotZero
        givenMaintenanceMarginRateIsNotZero
        givenMaxOpenInterestIsNotZero
        givenInitialMarginRateIsNotZero
        givenSkewScaleIsNotZero
    {
        changePrank({ msgSender: users.owner });

        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        IGlobalConfigurationBranch.UpdatePerpMarketConfigurationParams memory params = IGlobalConfigurationBranch
            .UpdatePerpMarketConfigurationParams({
            marketId: fuzzMarketConfig.marketId,
            name: "New market name",
            symbol: fuzzMarketConfig.marketSymbol,
            priceAdapter: fuzzMarketConfig.priceAdapter,
            initialMarginRateX18: fuzzMarketConfig.imr,
            maintenanceMarginRateX18: fuzzMarketConfig.mmr,
            maxOpenInterest: fuzzMarketConfig.maxOi,
            maxFundingVelocity: fuzzMarketConfig.maxFundingVelocity,
            skewScale: fuzzMarketConfig.skewScale,
            minTradeSizeX18: fuzzMarketConfig.minTradeSize,
            orderFees: OrderFees.Data({ makerFee: 0.0004e18, takerFee: 0.0008e18 })
        });

         // it should emit {LogUpdatePerpMarketConfiguration} event
         vm.expectEmit({ emitter: address(perpsEngine) });
         emit IGlobalConfigurationBranch.LogUpdatePerpMarketConfiguration(users.owner, fuzzMarketConfig.marketId);

        perpsEngine.updatePerpMarketConfiguration(params);

        // TODO
        // it should update perp market

    }
}
