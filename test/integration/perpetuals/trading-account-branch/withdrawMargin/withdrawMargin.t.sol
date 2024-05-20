// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Integration_Shared_Test } from "test/integration/shared/BaseIntegration.t.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { OrderBranch } from "@zaros/perpetuals/branches/OrderBranch.sol";
import { SettlementConfiguration } from "@zaros/perpetuals/leaves/SettlementConfiguration.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18 } from "@prb-math/SD59x18.sol";

contract WithdrawMargin_Integration_Test is Base_Integration_Shared_Test {
    function setUp() public override {
        Base_Integration_Shared_Test.setUp();
        changePrank({ msgSender: users.owner });
        configureSystemParameters();

        createPerpMarkets();
        changePrank({ msgSender: users.naruto });
    }

    function testFuzz_RevertGiven_TheAccountDoesNotExist(uint128 tradingAccountId) external {
        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Errors.AccountNotFound.selector, tradingAccountId, users.naruto)
        });
        perpsEngine.withdrawMargin(tradingAccountId, address(usdToken), 0);
    }

    modifier givenTheAccountExists() {
        _;
    }

    function test_RevertGiven_TheSenderIsNotAuthorized() external givenTheAccountExists {
        // it should revert
    }

    function testFuzz_RevertGiven_TheSenderIsNotAuthorized(
        uint256 amountToDeposit,
        uint256 amountToWithdraw
    )
        external
        givenTheAccountExists
    {
        amountToDeposit = bound({ x: amountToDeposit, min: USDZ_MIN_DEPOSIT_MARGIN, max: USDZ_DEPOSIT_CAP });
        amountToWithdraw = bound({ x: amountToWithdraw, min: USDZ_MIN_DEPOSIT_MARGIN, max: amountToDeposit });
        deal({ token: address(usdToken), to: users.naruto, give: amountToDeposit });

        uint128 tradingAccountId = createAccountAndDeposit(amountToDeposit, address(usdToken));
        changePrank({ msgSender: users.sasuke });

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Errors.AccountPermissionDenied.selector, tradingAccountId, users.sasuke)
        });
        perpsEngine.withdrawMargin(tradingAccountId, address(usdToken), amountToWithdraw);
    }

    modifier givenTheSenderIsAuthorized() {
        _;
    }

    function testFuzz_RevertWhen_TheAmountIsZero(uint256 amountToDeposit)
        external
        givenTheAccountExists
        givenTheSenderIsAuthorized
    {
        amountToDeposit = bound({ x: amountToDeposit, min: USDZ_MIN_DEPOSIT_MARGIN, max: USDZ_DEPOSIT_CAP });
        deal({ token: address(usdToken), to: users.naruto, give: amountToDeposit });

        uint128 tradingAccountId = createAccountAndDeposit(amountToDeposit, address(usdToken));

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "amount") });
        perpsEngine.withdrawMargin(tradingAccountId, address(usdToken), 0);
    }

    modifier whenTheAmountIsNotZero() {
        _;
    }

    function testFuzz_RevertGiven_ThereIsntEnoughMarginCollateral(
        uint256 amountToDeposit,
        uint256 amountToWithdraw
    )
        external
        givenTheAccountExists
        givenTheSenderIsAuthorized
        whenTheAmountIsNotZero
    {
        amountToDeposit = bound({ x: amountToDeposit, min: USDZ_MIN_DEPOSIT_MARGIN, max: USDZ_DEPOSIT_CAP });
        vm.assume(amountToWithdraw > amountToDeposit);
        uint256 expectedMarginCollateralBalance =
            convertTokenAmountToUd60x18(address(usdToken), amountToDeposit).intoUint256();
        deal({ token: address(usdToken), to: users.naruto, give: amountToDeposit });

        uint128 tradingAccountId = createAccountAndDeposit(amountToDeposit, address(usdToken));

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                Errors.InsufficientCollateralBalance.selector, amountToWithdraw, expectedMarginCollateralBalance
            )
        });
        perpsEngine.withdrawMargin(tradingAccountId, address(usdToken), amountToWithdraw);
    }

    modifier givenThereIsEnoughMarginCollateral() {
        _;
    }

    struct TestFuzz_RevertGiven_TheAccountWontMeetTheMarginRequirement_Context {
        MarketConfig fuzzMarketConfig;
        UD60x18 adjustedMarginRequirements;
        UD60x18 maxMarginValueUsd;
        uint128 tradingAccountId;
        int128 sizeDelta;
        SD59x18 marginBalanceUsdX18;
        UD60x18 requiredInitialMarginUsdX18;
        SD59x18 orderFeeUsdX18;
        UD60x18 settlementFeeUsdX18;
        bytes mockSignedReport;
    }

    function testFuzz_RevertGiven_TheAccountWontMeetTheMarginRequirement(
        uint256 marginValueUsd,
        uint256 amountToWithdraw,
        bool isLong,
        uint256 marketId
    )
        external
        givenTheAccountExists
        givenTheSenderIsAuthorized
        whenTheAmountIsNotZero
        givenThereIsEnoughMarginCollateral
    {
        TestFuzz_RevertGiven_TheAccountWontMeetTheMarginRequirement_Context memory ctx;
        ctx.fuzzMarketConfig = getFuzzMarketConfig(marketId);

        // avoids very small rounding errors in super edge cases
        ctx.adjustedMarginRequirements = ud60x18(ctx.fuzzMarketConfig.imr).mul(ud60x18(1.001e18));
        ctx.maxMarginValueUsd = ctx.adjustedMarginRequirements.mul(ud60x18(ctx.fuzzMarketConfig.maxSkew)).mul(
            ud60x18(ctx.fuzzMarketConfig.mockUsdPrice)
        );

        marginValueUsd =
            bound({ x: marginValueUsd, min: USDZ_MIN_DEPOSIT_MARGIN, max: ctx.maxMarginValueUsd.intoUint256() });
        amountToWithdraw = bound({ x: amountToWithdraw, min: USDZ_MIN_DEPOSIT_MARGIN, max: marginValueUsd });

        deal({ token: address(usdToken), to: users.naruto, give: marginValueUsd });

        ctx.tradingAccountId = createAccountAndDeposit(marginValueUsd, address(usdToken));
        int128 sizeDelta = fuzzOrderSizeDelta(
            FuzzOrderSizeDeltaParams({
                tradingAccountId: ctx.tradingAccountId,
                marketId: ctx.fuzzMarketConfig.marketId,
                settlementConfigurationId: SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID,
                initialMarginRate: ctx.adjustedMarginRequirements,
                marginValueUsd: ud60x18(marginValueUsd),
                maxSkew: ud60x18(ctx.fuzzMarketConfig.maxSkew),
                minTradeSize: ud60x18(ctx.fuzzMarketConfig.minTradeSize),
                price: ud60x18(ctx.fuzzMarketConfig.mockUsdPrice),
                isLong: isLong,
                shouldDiscountFees: true
            })
        );


        (, ,, ctx.orderFeeUsdX18, ctx.settlementFeeUsdX18,) =
        perpsEngine.simulateTrade(
            ctx.tradingAccountId,
            ctx.fuzzMarketConfig.marketId,
            SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID,
            sizeDelta
        );

        amountToWithdraw = amountToWithdraw - ctx.orderFeeUsdX18.intoUD60x18().intoUint256() - ctx.settlementFeeUsdX18.intoUint256();

        perpsEngine.createMarketOrder(
            OrderBranch.CreateMarketOrderParams({
                tradingAccountId: ctx.tradingAccountId,
                marketId: ctx.fuzzMarketConfig.marketId,
                sizeDelta: sizeDelta
            })
        );

        (ctx.marginBalanceUsdX18, ctx.requiredInitialMarginUsdX18,, ctx.orderFeeUsdX18, ctx.settlementFeeUsdX18,) =
        perpsEngine.simulateTrade(
            ctx.tradingAccountId,
            ctx.fuzzMarketConfig.marketId,
            SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID,
            sizeDelta
        );

        ctx.mockSignedReport = getMockedSignedReport(ctx.fuzzMarketConfig.streamId, ctx.fuzzMarketConfig.mockUsdPrice);

        changePrank({ msgSender: marketOrderKeepers[ctx.fuzzMarketConfig.marketId] });

        perpsEngine.fillMarketOrder(
            ctx.tradingAccountId, ctx.fuzzMarketConfig.marketId, feeRecipients, ctx.mockSignedReport
        );

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                Errors.InsufficientMargin.selector,
                ctx.tradingAccountId,
                0,
                ctx.requiredInitialMarginUsdX18,
                0
            )
        });

        changePrank({ msgSender: users.naruto });
        perpsEngine.withdrawMargin({
            tradingAccountId: ctx.tradingAccountId,
            collateralType: address(usdToken),
            amount: amountToWithdraw
        });
    }
}
