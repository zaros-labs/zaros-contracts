// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { Base_Integration_Shared_Test } from "test/integration/shared/BaseIntegration.t.sol";
import { IGlobalConfigurationBranch } from "@zaros/perpetuals/interfaces/IGlobalConfigurationBranch.sol";
import { OrderFees } from "@zaros/perpetuals/leaves/OrderFees.sol";
import { SettlementConfiguration } from "@zaros/perpetuals/leaves/SettlementConfiguration.sol";
import { IVerifierProxy } from "@zaros/external/chainlink/interfaces/IVerifierProxy.sol";

contract UpdateSettlementConfiguration_Integration_Test is Base_Integration_Shared_Test {
    function setUp() public override {
        Base_Integration_Shared_Test.setUp();
        changePrank({ msgSender: users.owner });
        configureSystemParameters();
        createPerpMarkets();
        changePrank({ msgSender: users.naruto });
    }

    function test_RevertGiven_MarketOrderConfigurationOnChainWithDifferentStrategy(uint256 marketId) external {
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
            strategy: SettlementConfiguration.Strategy.DATA_STREAMS_OFFCHAIN,
            isEnabled: false,
            fee: DEFAULT_SETTLEMENT_FEE,
            keeper: marketOrderKeepers[fuzzMarketConfig.marketId],
            data: abi.encode(marketOrderConfigurationData)
        });

        perpsEngine.updateSettlementConfiguration(
            uint128(marketId), SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID, newSettlementConfiguration
        );
    }

    function test_RevertGiven_OffChainConfigurationWithDifferentStrategy(uint256 marketId) external {
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
            strategy: SettlementConfiguration.Strategy.DATA_STREAMS_ONCHAIN,
            isEnabled: false,
            fee: DEFAULT_SETTLEMENT_FEE,
            keeper: marketOrderKeepers[fuzzMarketConfig.marketId],
            data: abi.encode(marketOrderConfigurationData)
        });

        perpsEngine.updateSettlementConfiguration(
            uint128(marketId), SettlementConfiguration.OFFCHAIN_ORDER_CONFIGURATION_ID, newSettlementConfiguration
        );
    }

    function test_GivenMarketOrderConfigurationOnChainWithYourStrategy(uint256 marketId) external {
        changePrank({ msgSender: users.owner });

        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        SettlementConfiguration.DataStreamsStrategy memory marketOrderConfigurationData = SettlementConfiguration
            .DataStreamsStrategy({
            chainlinkVerifier: IVerifierProxy(mockChainlinkVerifier),
            streamId: fuzzMarketConfig.streamId
        });
        SettlementConfiguration.Data memory newSettlementConfiguration = SettlementConfiguration.Data({
            strategy: SettlementConfiguration.Strategy.DATA_STREAMS_ONCHAIN,
            isEnabled: false,
            fee: DEFAULT_SETTLEMENT_FEE,
            keeper: marketOrderKeepers[fuzzMarketConfig.marketId],
            data: abi.encode(marketOrderConfigurationData)
        });

        // it should emit {LogUpdateSettlementConfiguration} event
        vm.expectEmit({ emitter: address(perpsEngine) });
        emit IGlobalConfigurationBranch.LogUpdateSettlementConfiguration(
            users.owner, fuzzMarketConfig.marketId, SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID
        );

        // it should update
        perpsEngine.updateSettlementConfiguration(
            uint128(fuzzMarketConfig.marketId),
            SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID,
            newSettlementConfiguration
        );
    }

    function test_GivenOffChainConfigurationWithYourStrategy(uint256 marketId) external {
        changePrank({ msgSender: users.owner });

        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        SettlementConfiguration.DataStreamsStrategy memory marketOrderConfigurationData = SettlementConfiguration
            .DataStreamsStrategy({
            chainlinkVerifier: IVerifierProxy(mockChainlinkVerifier),
            streamId: fuzzMarketConfig.streamId
        });
        SettlementConfiguration.Data memory newSettlementConfiguration = SettlementConfiguration.Data({
            strategy: SettlementConfiguration.Strategy.DATA_STREAMS_OFFCHAIN,
            isEnabled: false,
            fee: DEFAULT_SETTLEMENT_FEE,
            keeper: marketOrderKeepers[fuzzMarketConfig.marketId],
            data: abi.encode(marketOrderConfigurationData)
        });

        // it should emit {LogUpdateSettlementConfiguration} event
        vm.expectEmit({ emitter: address(perpsEngine) });
        emit IGlobalConfigurationBranch.LogUpdateSettlementConfiguration(
            users.owner, fuzzMarketConfig.marketId, SettlementConfiguration.OFFCHAIN_ORDER_CONFIGURATION_ID
        );

        // it should update
        perpsEngine.updateSettlementConfiguration(
            uint128(fuzzMarketConfig.marketId),
            SettlementConfiguration.OFFCHAIN_ORDER_CONFIGURATION_ID,
            newSettlementConfiguration
        );
    }
}
