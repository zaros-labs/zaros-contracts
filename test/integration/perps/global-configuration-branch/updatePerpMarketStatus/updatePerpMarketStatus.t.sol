// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { Base_Integration_Shared_Test } from "test/integration/shared/BaseIntegration.t.sol";
import { IGlobalConfigurationBranch } from "@zaros/perpetuals/interfaces/IGlobalConfigurationBranch.sol";
import { OrderFees } from "@zaros/perpetuals/leaves/OrderFees.sol";

contract UpdatePerpMarketStatus_Integration_Test is Base_Integration_Shared_Test {
    function setUp() public override {
        Base_Integration_Shared_Test.setUp();
        changePrank({ msgSender: users.owner });
        configureSystemParameters();
        createPerpMarkets();
        changePrank({ msgSender: users.naruto });
    }

    function test_RevertGiven_PerpMarketIsNotInitialized(uint256 marketId) external {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        uint128 marketIdNotInitialized = uint128(FINAL_MARKET_ID) + 1;

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Errors.PerpMarketNotInitialized.selector, marketIdNotInitialized)
        });

        changePrank({ msgSender: users.owner });
        perpsEngine.updatePerpMarketStatus(marketIdNotInitialized, true);
    }

    modifier givenPerpMarketIsInitialized() {
        _;
    }

    function test_RevertWhen_PerpMarketIsEnabledAndNewEnableStatusIsTrue(uint256 marketId) external givenPerpMarketIsInitialized {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Errors.PerpMarketAlreadyEnabled.selector, fuzzMarketConfig.marketId)
        });

        changePrank({ msgSender: users.owner });
        perpsEngine.updatePerpMarketStatus(fuzzMarketConfig.marketId, true);

    }

    function test_WhenPerpMarketIsEnabledAndNewEnableStatusIsFalse(uint256 marketId) external givenPerpMarketIsInitialized {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        changePrank({ msgSender: users.owner});

        // it should emit {LogDisablePerpMarket} event
        vm.expectEmit({ emitter: address(perpsEngine) });
        emit IGlobalConfigurationBranch.LogDisablePerpMarket(users.owner, fuzzMarketConfig.marketId);

        // it should remove market
        perpsEngine.updatePerpMarketStatus(fuzzMarketConfig.marketId, false);

    }

    function test_WhenPerpMarketIsNotEnabledAndNewEnableStatusIsTrue(uint256 marketId) external givenPerpMarketIsInitialized {
         MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        changePrank({ msgSender: users.owner});

        perpsEngine.updatePerpMarketStatus(fuzzMarketConfig.marketId, false);

        // it should emit {LogEnablePerpMarket} event
        vm.expectEmit({ emitter: address(perpsEngine) });
        emit IGlobalConfigurationBranch.LogEnablePerpMarket(users.owner, fuzzMarketConfig.marketId);

        // it should add market
        perpsEngine.updatePerpMarketStatus(fuzzMarketConfig.marketId, true);
    }

    function test_RevertWhen_PerpMarketIsNotEnabledAndNewEnableStatusIsFalse(uint256 marketId)
        external
        givenPerpMarketIsInitialized
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        changePrank({ msgSender: users.owner});

        perpsEngine.updatePerpMarketStatus(fuzzMarketConfig.marketId, false);

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Errors.PerpMarketAlreadyDisabled.selector, fuzzMarketConfig.marketId)
        });

        perpsEngine.updatePerpMarketStatus(fuzzMarketConfig.marketId, false);
    }
}
