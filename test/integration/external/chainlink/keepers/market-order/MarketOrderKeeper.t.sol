// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { Base_Integration_Shared_Test } from "test/integration/shared/BaseIntegration.t.sol";
import { GlobalConfigurationBranch } from "@zaros/perpetuals/branches/GlobalConfigurationBranch.sol";
import { IPerpsEngine } from "@zaros/perpetuals/PerpsEngine.sol";

import { console } from "forge-std/console.sol";

import { Markets } from "script/markets/Markets.sol";

import { MarketOrderKeeper } from "@zaros/external/chainlink/keepers/market-order/MarketOrderKeeper.sol";

// PRB Math dependencies
import { UD60x18, ud60x18, UNIT as UD_UNIT } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18, unary } from "@prb-math/SD59x18.sol";

import { OrderBranch } from "@zaros/perpetuals/branches/OrderBranch.sol";

import { SettlementConfiguration } from "@zaros/perpetuals/leaves/SettlementConfiguration.sol";

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

    function test_RevertWhen_AddressOfPerpsEngineIsZero(
        uint256 marketId,
        address settlementFeeRecipient
    )
        external
        givenInitializeContractWithSomeWrongInformation
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        Markets markets = new Markets();

        string memory streamId;

        (bool ok, bytes memory data) = address(markets).call(
            abi.encodeCall(
                markets.deployMarketOrderKeeper,
                (fuzzMarketConfig.marketId, users.owner, IPerpsEngine(address(0)), settlementFeeRecipient)
            )
        );

        bytes memory expectedError = abi.encodeWithSelector(Errors.ZeroInput.selector, "perpsEngine");

        // it should revert
        assertEq(data, expectedError);
    }

    function test_RevertWhen_AddressOfFeeRecipientIsZero(uint256 marketId)
        external
        givenInitializeContractWithSomeWrongInformation
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);
        Markets markets = new Markets();
        address settlementFeeRecipient = address(0);

        (bool ok, bytes memory data) = address(markets).call(
            abi.encodeCall(
                markets.deployMarketOrderKeeper,
                (fuzzMarketConfig.marketId, users.owner, perpsEngine, settlementFeeRecipient)
            )
        );

        bytes memory expectedError = abi.encodeWithSelector(Errors.ZeroInput.selector, "feeRecipient");

        // it should revert
        assertEq(data, expectedError);
    }

    function test_RevertWhen_MarketIdIsZero() external givenInitializeContractWithSomeWrongInformation {
        Markets markets = new Markets();
        address settlementFeeRecipient = address(0x20);

        (bool ok, bytes memory data) = address(markets).call(
            abi.encodeCall(markets.deployMarketOrderKeeper, (0, users.owner, perpsEngine, settlementFeeRecipient))
        );

        bytes memory expectedError = abi.encodeWithSelector(Errors.ZeroInput.selector, "marketId");

        // it should revert
        assertEq(data, expectedError);
    }

    function test_RevertWhen_StreamIdIsZero() external givenInitializeContractWithSomeWrongInformation {
        Markets markets = new Markets();
        address settlementFeeRecipient = address(0x20);

        (bool ok, bytes memory data) = address(markets).call(
            abi.encodeCall(
                markets.deployMarketOrderKeeper,
                (uint128(FINAL_MARKET_ID + 1), users.owner, perpsEngine, settlementFeeRecipient)
            )
        );

        bytes memory expectedError = abi.encodeWithSelector(Errors.ZeroInput.selector, "streamId");

        // it should revert
        assertEq(data, expectedError);
    }

    modifier givenInitializeContract() {
        _;
    }

    function test_GivenCallGetConfigFunction(uint256 marketId) external givenInitializeContract {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);
        address settlementFeeRecipient = address(0x20);

        address marketOrderKeeper =
            deployMarketOrderKeeper(fuzzMarketConfig.marketId, users.owner, perpsEngine, settlementFeeRecipient);

        (address keeperOwner, address forwarder, address perpsEngine, address feeRecipient, uint128 marketId) =
            MarketOrderKeeper(marketOrderKeeper).getConfig();

        // it should return keeper owner
        assertEq(users.owner, keeperOwner, "keeper owner is not correct");

        // it should return address of perps engine
        assertEq(address(perpsEngine), perpsEngine, "perps engine is not correct");

        // it should return address of fee recipient
        assertEq(settlementFeeRecipient, feeRecipient, "fee recipient is not correct");

        // it should return market id
        assertEq(fuzzMarketConfig.marketId, marketId, "market id is not correct");
    }

    modifier givenCallUpdateConfigFunction() {
        _;
    }

    function test_GivenCallUpdateConfigFunction(uint256 marketId)
        external
        givenInitializeContract
        givenCallUpdateConfigFunction
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);
        address settlementFeeRecipient = address(0x20);

        address marketOrderKeeper =
            deployMarketOrderKeeper(fuzzMarketConfig.marketId, users.owner, perpsEngine, settlementFeeRecipient);

        IPerpsEngine newPersEngine = IPerpsEngine(address(0x123));
        address newFeeRecipient = address(0x456);
        uint128 newMarketId = uint128(FINAL_MARKET_ID + 1);
        string memory newStreamId = "0x";

        changePrank({ msgSender: users.owner });

        // it should update the config
        MarketOrderKeeper(marketOrderKeeper).updateConfig(newPersEngine, newFeeRecipient, newMarketId, newStreamId);

        (address keeperOwner, address forwarder, address perpsEngine, address feeRecipient, uint128 marketId) =
            MarketOrderKeeper(marketOrderKeeper).getConfig();

        assertEq(users.owner, keeperOwner, "keeper owner is not correct");
        assertEq(address(newPersEngine), perpsEngine, "perps engine is not correct");
        assertEq(newFeeRecipient, feeRecipient, "fee recipient is not correct");
        assertEq(newMarketId, marketId, "market id is not correct");
        assertEq(newMarketId, marketId, "market id is not correct");
    }

    function test_WhenCallUpdateConfigAndAddressOfPerpsEngineIsZero(uint256 marketId)
        external
        givenInitializeContract
        givenCallUpdateConfigFunction
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);
        address settlementFeeRecipient = address(0x20);

        address marketOrderKeeper =
            deployMarketOrderKeeper(fuzzMarketConfig.marketId, users.owner, perpsEngine, settlementFeeRecipient);

        IPerpsEngine newPersEngine = IPerpsEngine(address(0));
        address newFeeRecipient = address(0x456);
        uint128 newMarketId = uint128(FINAL_MARKET_ID + 1);
        string memory newStreamId = "0x";

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "perpsEngine") });

        changePrank({ msgSender: users.owner });
        MarketOrderKeeper(marketOrderKeeper).updateConfig(newPersEngine, newFeeRecipient, newMarketId, newStreamId);
    }

    function test_WhenCallUpdateConfigAndAddressOfFeeRecipientIsZero(uint256 marketId)
        external
        givenInitializeContract
        givenCallUpdateConfigFunction
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);
        address settlementFeeRecipient = address(0x20);

        address marketOrderKeeper =
            deployMarketOrderKeeper(fuzzMarketConfig.marketId, users.owner, perpsEngine, settlementFeeRecipient);

        IPerpsEngine newPersEngine = IPerpsEngine(address(0x123));
        address newFeeRecipient = address(0);
        uint128 newMarketId = uint128(FINAL_MARKET_ID + 1);
        string memory newStreamId = "0x";

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "feeRecipient") });

        changePrank({ msgSender: users.owner });
        MarketOrderKeeper(marketOrderKeeper).updateConfig(newPersEngine, newFeeRecipient, newMarketId, newStreamId);
    }

    function test_WhenCallUpdateConfigAndMarketIdIsZero(uint256 marketId)
        external
        givenInitializeContract
        givenCallUpdateConfigFunction
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);
        address settlementFeeRecipient = address(0x20);

        address marketOrderKeeper =
            deployMarketOrderKeeper(fuzzMarketConfig.marketId, users.owner, perpsEngine, settlementFeeRecipient);

        IPerpsEngine newPersEngine = IPerpsEngine(address(0x123));
        address newFeeRecipient = address(0x456);
        uint128 newMarketId = 0;
        string memory newStreamId = "0x";

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "marketId") });

        changePrank({ msgSender: users.owner });
        MarketOrderKeeper(marketOrderKeeper).updateConfig(newPersEngine, newFeeRecipient, newMarketId, newStreamId);
    }

    function test_WhenCallUpdateConfigAndStreamIdIsZero(uint256 marketId)
        external
        givenInitializeContract
        givenCallUpdateConfigFunction
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);
        address settlementFeeRecipient = address(0x20);

        address marketOrderKeeper =
            deployMarketOrderKeeper(fuzzMarketConfig.marketId, users.owner, perpsEngine, settlementFeeRecipient);

        IPerpsEngine newPersEngine = IPerpsEngine(address(0x123));
        address newFeeRecipient = address(0x456);
        uint128 newMarketId = uint128(FINAL_MARKET_ID + 1);
        string memory newStreamId = "";

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "streamId") });

        changePrank({ msgSender: users.owner });
        MarketOrderKeeper(marketOrderKeeper).updateConfig(newPersEngine, newFeeRecipient, newMarketId, newStreamId);
    }

    function test_GivenCallPerformUpkeepFunction(
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        bool isLong,
        uint256 marketId
    )
        external
        givenInitializeContract
    {
        // changePrank({ msgSender: users.naruto });

        // MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);
        // address settlementFeeRecipient = address(0x20);

        // initialMarginRate =
        //     bound({ x: initialMarginRate, min: fuzzMarketConfig.marginRequirements, max: MAX_MARGIN_REQUIREMENTS });

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

        // bytes memory mockSignedReport =
        //     getMockedSignedReport(fuzzMarketConfig.streamId, fuzzMarketConfig.mockUsdPrice);

        // address marketOrderKeeper =
        //     deployMarketOrderKeeper(fuzzMarketConfig.marketId, users.owner, perpsEngine, settlementFeeRecipient);

        // changePrank({ msgSender: users.owner });
        // MarketOrderKeeper(marketOrderKeeper).setForwarder(users.owner);

        // bytes memory performData = abi.encode(mockSignedReport, tradingAccountId);

        // MarketOrderKeeper(marketOrderKeeper).performUpkeep(performData);

        // address marketOrderKeeper = marketOrderKeepers[fuzzMarketConfig.marketId];

        // changePrank({ msgSender: marketOrderKeeper });
        // perpsEngine.fillMarketOrder(tradingAccountId, fuzzMarketConfig.marketId, feeRecipients, mockSignedReport);

        // it should emit {LogSettleOrder} event
    }
}
