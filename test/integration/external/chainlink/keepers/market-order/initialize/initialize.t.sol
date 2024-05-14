// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { Base_Integration_Shared_Test } from "test/integration/shared/BaseIntegration.t.sol";
import { IPerpsEngine } from "@zaros/perpetuals/PerpsEngine.sol";
import { Markets } from "script/markets/Markets.sol";
import { MarketOrder } from "@zaros/perpetuals/leaves/MarketOrder.sol";

import { MarketOrderKeeper } from "@zaros/external/chainlink/keepers/market-order/MarketOrderKeeper.sol";

contract MarketOrderKeeper_Integration_Test is Base_Integration_Shared_Test {
    function setUp() public override {
        Base_Integration_Shared_Test.setUp();
        changePrank({ msgSender: users.owner });
        configureSystemParameters();

        createPerpMarkets();

        changePrank({ msgSender: users.naruto });
    }

    modifier givenInitializeContractWithSomeWrongInformation() {
        _;
    }

    function testFuzz_RevertWhen_AddressOfPerpsEngineIsZero(
        uint256 marketId,
        address settlementFeeRecipient
    )
        external
        givenInitializeContractWithSomeWrongInformation
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        Markets markets = new Markets();

        address marketOrderKeeperImplementation = address(new MarketOrderKeeper());

        (, bytes memory data) = address(markets).call(
            abi.encodeCall(
                markets.deployMarketOrderKeeper,
                (
                    fuzzMarketConfig.marketId,
                    users.owner,
                    IPerpsEngine(address(0)),
                    settlementFeeRecipient,
                    marketOrderKeeperImplementation
                )
            )
        );

        bytes memory expectedError = abi.encodeWithSelector(Errors.ZeroInput.selector, "perpsEngine");

        // it should revert
        assertEq(data, expectedError);
    }

    function testFuzz_RevertWhen_AddressOfFeeRecipientIsZero(uint256 marketId)
        external
        givenInitializeContractWithSomeWrongInformation
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);
        Markets markets = new Markets();
        address settlementFeeRecipient = address(0);
        address marketOrderKeeperImplementation = address(new MarketOrderKeeper());

        (, bytes memory data) = address(markets).call(
            abi.encodeCall(
                markets.deployMarketOrderKeeper,
                (
                    fuzzMarketConfig.marketId,
                    users.owner,
                    perpsEngine,
                    settlementFeeRecipient,
                    marketOrderKeeperImplementation
                )
            )
        );

        bytes memory expectedError = abi.encodeWithSelector(Errors.ZeroInput.selector, "feeRecipient");

        // it should revert
        assertEq(data, expectedError);
    }

    function test_RevertWhen_MarketIdIsZero() external givenInitializeContractWithSomeWrongInformation {
        Markets markets = new Markets();
        address settlementFeeRecipient = address(0x20);
        address marketOrderKeeperImplementation = address(new MarketOrderKeeper());

        (, bytes memory data) = address(markets).call(
            abi.encodeCall(
                markets.deployMarketOrderKeeper,
                (0, users.owner, perpsEngine, settlementFeeRecipient, marketOrderKeeperImplementation)
            )
        );

        bytes memory expectedError = abi.encodeWithSelector(Errors.ZeroInput.selector, "marketId");

        // it should revert
        assertEq(data, expectedError);
    }

    function test_RevertWhen_StreamIdIsZero() external givenInitializeContractWithSomeWrongInformation {
        Markets markets = new Markets();
        address settlementFeeRecipient = address(0x20);
        address marketOrderKeeperImplementation = address(new MarketOrderKeeper());

        (, bytes memory data) = address(markets).call(
            abi.encodeCall(
                markets.deployMarketOrderKeeper,
                (
                    uint128(FINAL_MARKET_ID + 1),
                    users.owner,
                    perpsEngine,
                    settlementFeeRecipient,
                    marketOrderKeeperImplementation
                )
            )
        );

        bytes memory expectedError = abi.encodeWithSelector(Errors.ZeroInput.selector, "streamId");

        // it should revert
        assertEq(data, expectedError);
    }
}
