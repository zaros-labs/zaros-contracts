// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { Base_Integration_Shared_Test } from "test/integration/shared/BaseIntegration.t.sol";
import { GlobalConfigurationBranch } from "@zaros/perpetuals/branches/GlobalConfigurationBranch.sol";
import { IPerpsEngine } from "@zaros/perpetuals/PerpsEngine.sol";
import { OrderBranch } from "@zaros/perpetuals/branches/OrderBranch.sol";
import { SettlementBranch } from "@zaros/perpetuals/branches/SettlementBranch.sol";
import { SettlementConfiguration } from "@zaros/perpetuals/leaves/SettlementConfiguration.sol";
import { Markets } from "script/markets/Markets.sol";
import { Log as AutomationLog } from "@zaros/external/chainlink/interfaces/ILogAutomation.sol";
import { MarketOrder } from "@zaros/perpetuals/leaves/MarketOrder.sol";

import { MarketOrderKeeper } from "@zaros/external/chainlink/keepers/market-order/MarketOrderKeeper.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18, unary } from "@prb-math/SD59x18.sol";

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

    modifier givenInitializeContract() {
        _;
    }

    function testFuzz_GivenCallGetConfigFunction(uint256 marketId) external givenInitializeContract {
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

        (address keeperOwner,, address perpsEngine, address feeRecipient, uint256 marketIdConfig) =
            MarketOrderKeeper(marketOrderKeeper).getConfig();

        // it should return keeper owner
        assertEq(users.owner, keeperOwner, "keeper owner is not correct");

        // it should return address of perps engine
        assertEq(address(perpsEngine), perpsEngine, "perps engine is not correct");

        // it should return address of fee recipient
        assertEq(settlementFeeRecipient, feeRecipient, "fee recipient is not correct");

        // it should return market id
        assertEq(fuzzMarketConfig.marketId, marketIdConfig, "market id is not correct");
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

    function testFuzz_WhenCallUpdateConfigAndAddressOfPerpsEngineIsZero(uint256 marketId)
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

    function testFuzz_WhenCallUpdateConfigAndAddressOfFeeRecipientIsZero(uint256 marketId)
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

    function testFuzz_WhenCallUpdateConfigAndMarketIdIsZero(uint256 marketId)
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

    function testFuzz_WhenCallUpdateConfigAndStreamIdIsZero(uint256 marketId)
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

    function testFuzz_GivenCallPerformUpkeepFunction(
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        bool isLong,
        uint256 marketId
    )
        external
        givenInitializeContract
    {
        changePrank({ msgSender: users.naruto });

        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        initialMarginRate =
            bound({ x: initialMarginRate, min: fuzzMarketConfig.marginRequirements, max: MAX_MARGIN_REQUIREMENTS });

        marginValueUsd = bound({ x: marginValueUsd, min: USDZ_MIN_DEPOSIT_MARGIN, max: USDZ_DEPOSIT_CAP });
        deal({ token: address(usdToken), to: users.naruto, give: marginValueUsd });

        uint128 tradingAccountId = createAccountAndDeposit(marginValueUsd, address(usdToken));
        int128 sizeDelta = fuzzOrderSizeDelta(
            FuzzOrderSizeDeltaParams({
                tradingAccountId: tradingAccountId,
                marketId: fuzzMarketConfig.marketId,
                settlementConfigurationId: SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID,
                initialMarginRate: ud60x18(initialMarginRate),
                marginValueUsd: ud60x18(marginValueUsd),
                maxOpenInterest: ud60x18(fuzzMarketConfig.maxOi),
                minTradeSize: ud60x18(fuzzMarketConfig.minTradeSize),
                price: ud60x18(fuzzMarketConfig.mockUsdPrice),
                isLong: isLong,
                shouldDiscountFees: true
            })
        );

        perpsEngine.createMarketOrder(
            OrderBranch.CreateMarketOrderParams({
                tradingAccountId: tradingAccountId,
                marketId: fuzzMarketConfig.marketId,
                sizeDelta: sizeDelta
            })
        );

        bytes memory mockSignedReport =
            getMockedSignedReport(fuzzMarketConfig.streamId, fuzzMarketConfig.mockUsdPrice);

        address marketOrderKeeper = marketOrderKeepers[fuzzMarketConfig.marketId];

        changePrank({ msgSender: users.owner });
        MarketOrderKeeper(marketOrderKeeper).setForwarder(marketOrderKeeper);

        bytes memory performData = abi.encode(mockSignedReport, abi.encode(tradingAccountId));

        UD60x18 firstFillPriceX18 =
            perpsEngine.getMarkPrice(fuzzMarketConfig.marketId, fuzzMarketConfig.mockUsdPrice, sizeDelta);

        (,,, SD59x18 firstOrderFeeUsdX18,,) = perpsEngine.simulateTrade(
            tradingAccountId,
            fuzzMarketConfig.marketId,
            SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID,
            sizeDelta
        );

        int256 firstOrderExpectedPnl =
            unary(firstOrderFeeUsdX18.add(ud60x18(DEFAULT_SETTLEMENT_FEE).intoSD59x18())).intoInt256();

        // it should emit {LogSettleOrder} event
        vm.expectEmit({ emitter: address(perpsEngine) });
        emit SettlementBranch.LogSettleOrder(
            marketOrderKeeper,
            tradingAccountId,
            fuzzMarketConfig.marketId,
            sizeDelta,
            firstFillPriceX18.intoUint256(),
            firstOrderFeeUsdX18.intoInt256(),
            DEFAULT_SETTLEMENT_FEE,
            firstOrderExpectedPnl,
            0
        );

        changePrank({ msgSender: marketOrderKeeper });
        MarketOrderKeeper(marketOrderKeeper).performUpkeep(performData);
    }

    function testFuzz_RevertGiven_CallCheckLogFunction(
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        bool isLong,
        uint256 marketId
    )
        external
        givenInitializeContract
    {
        // TODO
        // changePrank({ msgSender: users.naruto });

        // MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        // initialMarginRate =
        //     bound({ x: initialMarginRate, min: fuzzMarketConfig.marginRequirements, max: MAX_MARGIN_REQUIREMENTS
        // });

        // marginValueUsd = bound({ x: marginValueUsd, min: USDZ_MIN_DEPOSIT_MARGIN, max: USDZ_DEPOSIT_CAP });
        // deal({ token: address(usdToken), to: users.naruto, give: marginValueUsd });

        // uint128 tradingAccountId = createAccountAndDeposit(marginValueUsd, address(usdToken));
        // int128 sizeDelta = fuzzOrderSizeDelta(
        //     FuzzOrderSizeDeltaParams({
        //         tradingAccountId: tradingAccountId,
        //         marketId: fuzzMarketConfig.marketId,
        //         settlementConfigurationId: SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID,
        //         initialMarginRate: ud60x18(initialMarginRate),
        //         marginValueUsd: ud60x18(marginValueUsd),
        //         maxOpenInterest: ud60x18(fuzzMarketConfig.maxOi),
        //         minTradeSize: ud60x18(fuzzMarketConfig.minTradeSize),
        //         price: ud60x18(fuzzMarketConfig.mockUsdPrice),
        //         isLong: isLong,
        //         shouldDiscountFees: true
        //     })
        // );

        // perpsEngine.createMarketOrder(
        //     OrderBranch.CreateMarketOrderParams({
        //         tradingAccountId: tradingAccountId,
        //         marketId: fuzzMarketConfig.marketId,
        //         sizeDelta: sizeDelta
        //     })
        // );

        // bytes memory empty;

        // bytes32[] memory topics = new bytes32[](4);
        // topics[0] = keccak256(abi.encode("Log(address,uint128,uint256)"));
        // topics[1] = keccak256(abi.encode(address(perpsEngine)));
        // topics[2] = keccak256(abi.encode(tradingAccountId));
        // topics[3] = keccak256(abi.encode(fuzzMarketConfig.marketId));

        // MarketOrder.Data memory marketOrder =
        //     MarketOrder.Data({ marketId: fuzzMarketConfig.marketId, sizeDelta: sizeDelta, timestamp: 0 });

        // bytes memory data = abi.encode(marketOrder);

        // AutomationLog memory mockedLog = AutomationLog({
        //     index: 0,
        //     timestamp: 0,
        //     txHash: 0,
        //     blockNumber: 0,
        //     blockHash: 0,
        //     source: address(0),
        //     topics: topics,
        //     data: data
        // });

        // address marketOrderKeeper = marketOrderKeepers[fuzzMarketConfig.marketId];
        // it should revert
        // MarketOrderKeeper(marketOrderKeeper).checkLog(mockedLog, empty);
    }

    function test_GivenCallCheckCallbackFunction() external givenInitializeContract {
        // TODO
        // it should return upkeepNeeded
        // it should return performData
    }
}
