// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { Base_Integration_Shared_Test } from "test/integration/shared/BaseIntegration.t.sol";
import { IPerpsEngine } from "@zaros/perpetuals/PerpsEngine.sol";
import { Markets } from "script/markets/Markets.sol";
import { MarketOrder } from "@zaros/perpetuals/leaves/MarketOrder.sol";

import { MarketOrderKeeper } from "@zaros/external/chainlink/keepers/market-order/MarketOrderKeeper.sol";

contract MarketOrderKeeperUpdateConfig_Integration_Test is Base_Integration_Shared_Test {
    function setUp() public override {
        Base_Integration_Shared_Test.setUp();
        changePrank({ msgSender: users.owner });
        configureSystemParameters();

        createPerpMarkets();

        changePrank({ msgSender: users.naruto });
    }

    modifier givenInitializeContract() {
        _;
    }

    modifier givenCallUpdateConfigFunction() {
        _;
    }

    function testFuzz_GivenCallUpdateConfigFunction(uint256 marketId)
        external
        givenInitializeContract
        givenCallUpdateConfigFunction
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);
        address settlementFeeRecipient = address(0x20);
        address marketOrderKeeperImplementation = address(new MarketOrderKeeper());

        address marketOrderKeeper = deployMarketOrderKeeper(
            fuzzMarketConfig.marketId,
            users.owner,
            perpsEngine,
            settlementFeeRecipient,
            marketOrderKeeperImplementation
        );

        IPerpsEngine newPersEngine = IPerpsEngine(address(0x123));
        address newFeeRecipient = address(0x456);
        uint128 newMarketId = uint128(FINAL_MARKET_ID + 1);
        string memory newStreamId = "0x";

        changePrank({ msgSender: users.owner });

        // it should update the config
        MarketOrderKeeper(marketOrderKeeper).updateConfig(newPersEngine, newFeeRecipient, newMarketId, newStreamId);

        (address keeperOwner,, address perpsEngine, address feeRecipient, uint256 marketIdConfig) =
            MarketOrderKeeper(marketOrderKeeper).getConfig();

        assertEq(users.owner, keeperOwner, "keeper owner is not correct");
        assertEq(address(newPersEngine), perpsEngine, "perps engine is not correct");
        assertEq(newFeeRecipient, feeRecipient, "fee recipient is not correct");
        assertEq(newMarketId, marketIdConfig, "market id is not correct");
    }

    function testFuzz_WhenAddressOfPerpsEngineIsZero(uint256 marketId)
        external
        givenInitializeContract
        givenCallUpdateConfigFunction
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);
        address settlementFeeRecipient = address(0x20);
        address marketOrderKeeperImplementation = address(new MarketOrderKeeper());

        address marketOrderKeeper = deployMarketOrderKeeper(
            fuzzMarketConfig.marketId,
            users.owner,
            perpsEngine,
            settlementFeeRecipient,
            marketOrderKeeperImplementation
        );

        IPerpsEngine newPersEngine = IPerpsEngine(address(0));
        address newFeeRecipient = address(0x456);
        uint128 newMarketId = uint128(FINAL_MARKET_ID + 1);
        string memory newStreamId = "0x";

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "perpsEngine") });

        changePrank({ msgSender: users.owner });
        MarketOrderKeeper(marketOrderKeeper).updateConfig(newPersEngine, newFeeRecipient, newMarketId, newStreamId);
    }

    function testFuzz_WhenAddressOfFeeRecipientIsZero(uint256 marketId)
        external
        givenInitializeContract
        givenCallUpdateConfigFunction
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);
        address settlementFeeRecipient = address(0x20);
        address marketOrderKeeperImplementation = address(new MarketOrderKeeper());

        address marketOrderKeeper = deployMarketOrderKeeper(
            fuzzMarketConfig.marketId,
            users.owner,
            perpsEngine,
            settlementFeeRecipient,
            marketOrderKeeperImplementation
        );

        IPerpsEngine newPersEngine = IPerpsEngine(address(0x123));
        address newFeeRecipient = address(0);
        uint128 newMarketId = uint128(FINAL_MARKET_ID + 1);
        string memory newStreamId = "0x";

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "feeRecipient") });

        changePrank({ msgSender: users.owner });
        MarketOrderKeeper(marketOrderKeeper).updateConfig(newPersEngine, newFeeRecipient, newMarketId, newStreamId);
    }

    function testFuzz_WhenMarketIdIsZero(uint256 marketId)
        external
        givenInitializeContract
        givenCallUpdateConfigFunction
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);
        address settlementFeeRecipient = address(0x20);
        address marketOrderKeeperImplementation = address(new MarketOrderKeeper());

        address marketOrderKeeper = deployMarketOrderKeeper(
            fuzzMarketConfig.marketId,
            users.owner,
            perpsEngine,
            settlementFeeRecipient,
            marketOrderKeeperImplementation
        );

        IPerpsEngine newPersEngine = IPerpsEngine(address(0x123));
        address newFeeRecipient = address(0x456);
        uint128 newMarketId = 0;
        string memory newStreamId = "0x";

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "marketId") });

        changePrank({ msgSender: users.owner });
        MarketOrderKeeper(marketOrderKeeper).updateConfig(newPersEngine, newFeeRecipient, newMarketId, newStreamId);
    }

    function testFuzz_WhenStreamIdIsZero(uint256 marketId)
        external
        givenInitializeContract
        givenCallUpdateConfigFunction
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);
        address settlementFeeRecipient = address(0x20);
        address marketOrderKeeperImplementation = address(new MarketOrderKeeper());

        address marketOrderKeeper = deployMarketOrderKeeper(
            fuzzMarketConfig.marketId,
            users.owner,
            perpsEngine,
            settlementFeeRecipient,
            marketOrderKeeperImplementation
        );

        IPerpsEngine newPersEngine = IPerpsEngine(address(0x123));
        address newFeeRecipient = address(0x456);
        uint128 newMarketId = uint128(FINAL_MARKET_ID + 1);
        string memory newStreamId = "";

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "streamId") });

        changePrank({ msgSender: users.owner });
        MarketOrderKeeper(marketOrderKeeper).updateConfig(newPersEngine, newFeeRecipient, newMarketId, newStreamId);
    }
}
