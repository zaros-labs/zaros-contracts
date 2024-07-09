// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { Base_Test } from "test/Base.t.sol";
import { GlobalConfigurationBranch } from "@zaros/perpetuals/branches/GlobalConfigurationBranch.sol";
import { SettlementConfiguration } from "@zaros/perpetuals/leaves/SettlementConfiguration.sol";
import { IVerifierProxy } from "@zaros/external/chainlink/interfaces/IVerifierProxy.sol";

contract UpdateSettlementConfiguration_Integration_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner });
        configureSystemParameters();
        createPerpMarkets();
        changePrank({ msgSender: users.naruto });
    }

    function testFuzz_RevertWhen_PerpMarketIsNotInitialized(uint256 marketId) external {
        uint128 marketIdNotInitialized = uint128(FINAL_MARKET_ID) + 1;

        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Errors.PerpMarketNotInitialized.selector, marketIdNotInitialized)
        });

        SettlementConfiguration.DataStreamsStrategy memory marketOrderConfigurationData = SettlementConfiguration
            .DataStreamsStrategy({
            chainlinkVerifier: IVerifierProxy(mockChainlinkVerifier),
            streamId: fuzzMarketConfig.streamId
        });
        SettlementConfiguration.Data memory newSettlementConfiguration = SettlementConfiguration.Data({
            strategy: SettlementConfiguration.Strategy.DATA_STREAMS_DEFAULT,
            isEnabled: false,
            fee: DEFAULT_SETTLEMENT_FEE,
            keeper: marketOrderKeepers[fuzzMarketConfig.marketId],
            data: abi.encode(marketOrderConfigurationData)
        });

        changePrank({ msgSender: users.owner });
        perpsEngine.updateSettlementConfiguration(
            marketIdNotInitialized, SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID, newSettlementConfiguration
        );
    }

    modifier whenPerpMarketIsInitialized() {
        _;
    }

    function test_RevertWhen_MarketOrderConfigurationOnChainHasWrongStrategy(uint256 marketId)
        external
        whenPerpMarketIsInitialized
    {
        changePrank({ msgSender: users.owner });

        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.InvalidSettlementStrategy.selector) });

        SettlementConfiguration.DataStreamsStrategy memory marketOrderConfigurationData = SettlementConfiguration
            .DataStreamsStrategy({
            chainlinkVerifier: IVerifierProxy(mockChainlinkVerifier),
            streamId: fuzzMarketConfig.streamId
        });
        SettlementConfiguration.Data memory newSettlementConfiguration = SettlementConfiguration.Data({
            strategy: SettlementConfiguration.Strategy.DATA_STREAMS_DEFAULT,
            isEnabled: false,
            fee: DEFAULT_SETTLEMENT_FEE,
            keeper: marketOrderKeepers[fuzzMarketConfig.marketId],
            data: abi.encode(marketOrderConfigurationData)
        });

        perpsEngine.updateSettlementConfiguration(
            fuzzMarketConfig.marketId,
            SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID,
            newSettlementConfiguration
        );
    }

    function test_RevertWhen_OffChainConfigurationHasWrongStrategy(uint256 marketId)
        external
        whenPerpMarketIsInitialized
    {
        changePrank({ msgSender: users.owner });

        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.InvalidSettlementStrategy.selector) });

        SettlementConfiguration.DataStreamsStrategy memory marketOrderConfigurationData = SettlementConfiguration
            .DataStreamsStrategy({
            chainlinkVerifier: IVerifierProxy(mockChainlinkVerifier),
            streamId: fuzzMarketConfig.streamId
        });
        SettlementConfiguration.Data memory newSettlementConfiguration = SettlementConfiguration.Data({
            strategy: SettlementConfiguration.Strategy.DATA_STREAMS_DEFAULT,
            isEnabled: false,
            fee: DEFAULT_SETTLEMENT_FEE,
            keeper: marketOrderKeepers[fuzzMarketConfig.marketId],
            data: abi.encode(marketOrderConfigurationData)
        });

        perpsEngine.updateSettlementConfiguration(
            fuzzMarketConfig.marketId,
            SettlementConfiguration.SIGNED_ORDERS_CONFIGURATION_ID,
            newSettlementConfiguration
        );
    }

    function test_WhenMarketOrderConfigurationOnChainHasCorrectStrategy(uint256 marketId)
        external
        whenPerpMarketIsInitialized
    {
        changePrank({ msgSender: users.owner });

        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        SettlementConfiguration.DataStreamsStrategy memory marketOrderConfigurationData = SettlementConfiguration
            .DataStreamsStrategy({
            chainlinkVerifier: IVerifierProxy(mockChainlinkVerifier),
            streamId: fuzzMarketConfig.streamId
        });
        SettlementConfiguration.Data memory newSettlementConfiguration = SettlementConfiguration.Data({
            strategy: SettlementConfiguration.Strategy.DATA_STREAMS_DEFAULT,
            isEnabled: false,
            fee: DEFAULT_SETTLEMENT_FEE,
            keeper: marketOrderKeepers[fuzzMarketConfig.marketId],
            data: abi.encode(marketOrderConfigurationData)
        });

        // it should emit {LogUpdateSettlementConfiguration} event
        vm.expectEmit({ emitter: address(perpsEngine) });
        emit GlobalConfigurationBranch.LogUpdateSettlementConfiguration(
            users.owner, fuzzMarketConfig.marketId, SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID
        );

        // it should update
        perpsEngine.updateSettlementConfiguration(
            uint128(fuzzMarketConfig.marketId),
            SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID,
            newSettlementConfiguration
        );
    }

    function test_WhenOffChainConfigurationHasCorrectStrategy(uint256 marketId)
        external
        whenPerpMarketIsInitialized
    {
        changePrank({ msgSender: users.owner });

        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        SettlementConfiguration.DataStreamsStrategy memory marketOrderConfigurationData = SettlementConfiguration
            .DataStreamsStrategy({
            chainlinkVerifier: IVerifierProxy(mockChainlinkVerifier),
            streamId: fuzzMarketConfig.streamId
        });
        SettlementConfiguration.Data memory newSettlementConfiguration = SettlementConfiguration.Data({
            strategy: SettlementConfiguration.Strategy.DATA_STREAMS_DEFAULT,
            isEnabled: false,
            fee: DEFAULT_SETTLEMENT_FEE,
            keeper: marketOrderKeepers[fuzzMarketConfig.marketId],
            data: abi.encode(marketOrderConfigurationData)
        });

        // it should emit {LogUpdateSettlementConfiguration} event
        vm.expectEmit({ emitter: address(perpsEngine) });
        emit GlobalConfigurationBranch.LogUpdateSettlementConfiguration(
            users.owner, fuzzMarketConfig.marketId, SettlementConfiguration.SIGNED_ORDERS_CONFIGURATION_ID
        );

        // it should update
        perpsEngine.updateSettlementConfiguration(
            uint128(fuzzMarketConfig.marketId),
            SettlementConfiguration.SIGNED_ORDERS_CONFIGURATION_ID,
            newSettlementConfiguration
        );
    }
}
