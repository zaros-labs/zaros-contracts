pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { Base_Test } from "test/Base.t.sol";
import { TradingAccountBranch } from "@zaros/perpetuals/branches/TradingAccountBranch.sol";
import { MockERC20 } from "test/mocks/MockERC20.sol";
import { TradingAccount } from "../../../../../src/perpetuals/leaves/TradingAccount.sol";
import { GlobalConfiguration } from "../../../../../src/perpetuals/leaves/GlobalConfiguration.sol";
import { FeeRecipients } from "../../../../../src/perpetuals/leaves/FeeRecipients.sol";
import { Position } from "../../../../../src/perpetuals/leaves/Position.sol";
import { MarginCollateralConfiguration } from "@zaros/perpetuals/leaves/MarginCollateralConfiguration.sol";

import { TradingAccountHarness } from "test/harnesses/perpetuals/leaves/TradingAccountHarness.sol";

import { console } from "forge-std/console.sol";

// PRB Math dependencies
import { UD60x18, ud60x18, ZERO as UD60x18_ZERO } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18, ZERO as SD_ZERO, unary } from "@prb-math/SD59x18.sol";
import { PRBMathCastingUint256 } from "@prb-math/casting/Uint256.sol";

contract DeductAccountMargin_Unit_Test is Base_Test, TradingAccountHarness {
    /// @dev usually the funciton is called if pnl is < 0

    struct DeductAccountMarginContext {
        UD60x18 marginCollateralBalanceX18;
        UD60x18 marginCollateralPriceUsdX18;
        UD60x18 settlementFeeDeductedUsdX18;
        UD60x18 withdrawnMarginUsdX18;
        bool isMissingMargin;
        UD60x18 orderFeeDeductedUsdX18;
        UD60x18 pnlDeductedUsdX18;
    }

    struct FillOrderContext {
        address usdToken;
        uint128 marketId;
        uint128 tradingAccountId;
        UD60x18 orderFeeUsdX18;
        UD60x18 settlementFeeUsdX18;
        SD59x18 sizeDelta;
        UD60x18 fillPrice;
        SD59x18 pnl;
        SD59x18 fundingFeePerUnit;
        SD59x18 fundingRate;
        Position.Data newPosition;
        UD60x18 newOpenInterest;
        SD59x18 newSkew;
    }

    function setUp() public override {
        Base_Test.setUp();
        // do we need these?
        changePrank({ msgSender: users.owner });
        configureSystemParameters();
        createPerpMarkets();
        changePrank({ msgSender: users.naruto });
    }

    modifier whenThereIsCollateralLiquidationPriority() {
        _;
    }

    function test_GivenTheAccountHasAMarginBalanceDifferentFrom0(
        uint256 marginValueUsd,
        uint256 feeAmount,
        uint256 randomFeeAmount1,
        uint256 randomFeeAmount2
    )
        external
        whenThereIsCollateralLiquidationPriority
    {
        // it should break the for loop

        marginValueUsd = bound({ x: marginValueUsd, min: USDC_MIN_DEPOSIT_MARGIN, max: USDC_DEPOSIT_CAP });

        feeAmount = bound({ x: feeAmount, min: USDC_MIN_DEPOSIT_MARGIN - 1, max: USDC_DEPOSIT_CAP - 1 });
        randomFeeAmount1 = bound({ x: feeAmount, min: USDC_MIN_DEPOSIT_MARGIN - 1, max: USDC_DEPOSIT_CAP - 1 });
        randomFeeAmount2 = bound({ x: feeAmount, min: USDC_MIN_DEPOSIT_MARGIN - 1, max: USDC_DEPOSIT_CAP - 1 });

        deal({ token: address(usdc), to: users.naruto, give: marginValueUsd });

        uint128 tradingAccountId = createAccountAndDeposit(marginValueUsd, address(usdc));

        FillOrderContext memory ctx;

        ctx.settlementFeeUsdX18 = ud60x18(randomFeeAmount1);

        UD60x18 pnlUsdX18 = ud60x18(feeAmount);

        UD60x18 orderFeeUsdX18 = ud60x18(randomFeeAmount2);

        UD60x18 marginCollateralBalanceX18 = TradingAccountHarness(address(perpsEngine))
            .exposed_getMarginCollateralBalance(tradingAccountId, address(usdc));

        perpsEngine.exposed_withdrawMarginUsd(
            tradingAccountId, address(usdc), ud60x18(marginValueUsd), marginCollateralBalanceX18, users.naruto
        );

        TradingAccountHarness(address(perpsEngine)).exposed_deductAccountMargin({
            tradingAccountId: tradingAccountId,
            feeRecipients: FeeRecipients.Data({
                marginCollateralRecipient: MSIG_ADDRESS,
                orderFeeRecipient: MSIG_ADDRESS,
                settlementFeeRecipient: MSIG_ADDRESS
            }),
            pnlUsdX18: pnlUsdX18,
            orderFeeUsdX18: orderFeeUsdX18,
            settlementFeeUsdX18: ctx.settlementFeeUsdX18
        });
    }

    modifier givenTheAccountHasAMarginBalanceOf0() {
        _;
    }

    function testFuzz_WhenTheSettlementFeeUsdX18IsZero(
        uint256 marginValueUsd,
        uint256 feeAmount,
        uint256 randomFeeAmount1,
        uint256 randomFeeAmount2
    )
        external
        givenTheAccountHasAMarginBalanceOf0
        whenThereIsCollateralLiquidationPriority
    {
        // it should skip the settlementFeeUsdX18 check
        marginValueUsd = bound({ x: marginValueUsd, min: USDC_MIN_DEPOSIT_MARGIN, max: USDC_DEPOSIT_CAP });

        feeAmount = bound({ x: feeAmount, min: USDC_MIN_DEPOSIT_MARGIN - 1, max: USDC_DEPOSIT_CAP - 1 });
        randomFeeAmount1 = bound({ x: feeAmount, min: USDC_MIN_DEPOSIT_MARGIN - 1, max: USDC_DEPOSIT_CAP - 1 });
        randomFeeAmount2 = bound({ x: feeAmount, min: USDC_MIN_DEPOSIT_MARGIN - 1, max: USDC_DEPOSIT_CAP - 1 });

        deal({ token: address(usdc), to: users.naruto, give: marginValueUsd });

        uint128 tradingAccountId = createAccountAndDeposit(marginValueUsd, address(usdc));

        FillOrderContext memory ctx;

        ctx.settlementFeeUsdX18 = ud60x18(randomFeeAmount1);

        UD60x18 pnlUsdX18 = ud60x18(feeAmount);

        UD60x18 orderFeeUsdX18 = ud60x18(randomFeeAmount2);

        TradingAccountHarness(address(perpsEngine)).exposed_deductAccountMargin({
            tradingAccountId: tradingAccountId,
            feeRecipients: FeeRecipients.Data({
                marginCollateralRecipient: MSIG_ADDRESS,
                orderFeeRecipient: MSIG_ADDRESS,
                settlementFeeRecipient: MSIG_ADDRESS
            }),
            pnlUsdX18: pnlUsdX18,
            orderFeeUsdX18: orderFeeUsdX18,
            settlementFeeUsdX18: ctx.settlementFeeUsdX18
        });
    }

    function testFuzz_WhenSettlementFeeUsdX18IsGreaterThanZeroAndIfTheAlreadyDeductedSettlementFeeSettlementFeeDeductedUsdX18IsLessThanTheTotalSettlementFeeUsdX18(
        uint256 marginValueUsd,
        uint256 feeAmount,
        uint256 randomFeeAmount1,
        uint256 randomFeeAmount2
    )
        external
        givenTheAccountHasAMarginBalanceOf0
        whenThereIsCollateralLiquidationPriority
    {
        // it should deduct the settlement fee from the account's margin balance
        // it should return isMissingMargin a boolean indicating whether there was insufficient margin to cover the
        // fee

        marginValueUsd = bound({ x: marginValueUsd, min: USDC_MIN_DEPOSIT_MARGIN, max: USDC_DEPOSIT_CAP });

        feeAmount = bound({ x: feeAmount, min: USDC_MIN_DEPOSIT_MARGIN - 1, max: USDC_DEPOSIT_CAP - 1 });
        randomFeeAmount1 = bound({ x: feeAmount, min: USDC_MIN_DEPOSIT_MARGIN - 1, max: USDC_DEPOSIT_CAP - 1 });
        randomFeeAmount2 = bound({ x: feeAmount, min: USDC_MIN_DEPOSIT_MARGIN - 1, max: USDC_DEPOSIT_CAP - 1 });

        deal({ token: address(usdc), to: users.naruto, give: marginValueUsd });

        uint128 tradingAccountId = createAccountAndDeposit(marginValueUsd, address(usdc));

        FillOrderContext memory ctx;

        ctx.settlementFeeUsdX18 = ud60x18(feeAmount);

        UD60x18 pnlUsdX18 = ud60x18(randomFeeAmount1);

        UD60x18 orderFeeUsdX18 = ud60x18(randomFeeAmount2);

        TradingAccountHarness(address(perpsEngine)).exposed_deductAccountMargin({
            tradingAccountId: tradingAccountId,
            feeRecipients: FeeRecipients.Data({
                marginCollateralRecipient: MSIG_ADDRESS,
                orderFeeRecipient: MSIG_ADDRESS,
                settlementFeeRecipient: MSIG_ADDRESS
            }),
            pnlUsdX18: pnlUsdX18,
            orderFeeUsdX18: orderFeeUsdX18,
            settlementFeeUsdX18: ctx.settlementFeeUsdX18
        });
    }

    function testFuzz_WhenTheOrderFeeUsdX18IsZero(
        uint256 marginValueUsd,
        uint256 feeAmount,
        uint256 randomFeeAmount1,
        uint256 randomFeeAmount2
    )
        external
        givenTheAccountHasAMarginBalanceOf0
        whenThereIsCollateralLiquidationPriority
    {
        // it should skip the orderFeeUsdX18 check

        marginValueUsd = bound({ x: marginValueUsd, min: USDC_MIN_DEPOSIT_MARGIN, max: USDC_DEPOSIT_CAP });

        feeAmount = bound({ x: feeAmount, min: USDC_MIN_DEPOSIT_MARGIN - 1, max: USDC_DEPOSIT_CAP - 1 });
        randomFeeAmount1 = bound({ x: feeAmount, min: USDC_MIN_DEPOSIT_MARGIN - 1, max: USDC_DEPOSIT_CAP - 1 });
        randomFeeAmount2 = bound({ x: feeAmount, min: USDC_MIN_DEPOSIT_MARGIN - 1, max: USDC_DEPOSIT_CAP - 1 });

        deal({ token: address(usdc), to: users.naruto, give: marginValueUsd });

        uint128 tradingAccountId = createAccountAndDeposit(marginValueUsd, address(usdc));

        FillOrderContext memory ctx;

        ctx.settlementFeeUsdX18 = ud60x18(randomFeeAmount1);

        UD60x18 pnlUsdX18 = ud60x18(feeAmount);

        UD60x18 orderFeeUsdX18 = ud60x18(randomFeeAmount2);

        TradingAccountHarness(address(perpsEngine)).exposed_deductAccountMargin({
            tradingAccountId: tradingAccountId,
            feeRecipients: FeeRecipients.Data({
                marginCollateralRecipient: MSIG_ADDRESS,
                orderFeeRecipient: MSIG_ADDRESS,
                settlementFeeRecipient: MSIG_ADDRESS
            }),
            pnlUsdX18: pnlUsdX18,
            orderFeeUsdX18: orderFeeUsdX18,
            settlementFeeUsdX18: ctx.settlementFeeUsdX18
        });
    }

    function testFuzz_WhenTheOrderFeeUsdX18IsGreaterThanZeroAndIfTheAlreadyDeductedOrderFeeOrderFeeDeductedUsdX18IsLessThanTheTotalOrderFeeUsdX18(
        uint256 marginValueUsd,
        uint256 feeAmount,
        uint256 randomFeeAmount1,
        uint256 randomFeeAmount2
    )
        external
        givenTheAccountHasAMarginBalanceOf0
        whenThereIsCollateralLiquidationPriority
    {
        // it should deduct the order fee from the account's margin balance
        // it should return isMissingMargin a boolean indicating whether there was insufficient margin to cover the
        // fee

        marginValueUsd = bound({ x: marginValueUsd, min: USDC_MIN_DEPOSIT_MARGIN, max: USDC_DEPOSIT_CAP });

        feeAmount = bound({ x: feeAmount, min: USDC_MIN_DEPOSIT_MARGIN - 1, max: USDC_DEPOSIT_CAP - 1 });
        randomFeeAmount1 = bound({ x: feeAmount, min: USDC_MIN_DEPOSIT_MARGIN - 1, max: USDC_DEPOSIT_CAP - 1 });
        randomFeeAmount2 = bound({ x: feeAmount, min: USDC_MIN_DEPOSIT_MARGIN - 1, max: USDC_DEPOSIT_CAP - 1 });

        deal({ token: address(usdc), to: users.naruto, give: marginValueUsd });

        uint128 tradingAccountId = createAccountAndDeposit(marginValueUsd, address(usdc));

        FillOrderContext memory ctx;

        ctx.settlementFeeUsdX18 = ud60x18(randomFeeAmount1);

        UD60x18 pnlUsdX18 = ud60x18(randomFeeAmount2);

        UD60x18 orderFeeUsdX18 = ud60x18(feeAmount);

        TradingAccountHarness(address(perpsEngine)).exposed_deductAccountMargin({
            tradingAccountId: tradingAccountId,
            feeRecipients: FeeRecipients.Data({
                marginCollateralRecipient: MSIG_ADDRESS,
                orderFeeRecipient: MSIG_ADDRESS,
                settlementFeeRecipient: MSIG_ADDRESS
            }),
            pnlUsdX18: pnlUsdX18,
            orderFeeUsdX18: orderFeeUsdX18,
            settlementFeeUsdX18: ctx.settlementFeeUsdX18
        });
    }

    function testFuzz_WhenPnlUsdX18IsZero(
        uint256 marginValueUsd,
        uint256 feeAmount,
        uint256 randomFeeAmount1,
        uint256 randomFeeAmount2
    )
        external
        givenTheAccountHasAMarginBalanceOf0
        whenThereIsCollateralLiquidationPriority
    {
        // it should skip the pnlUsdX18 check

        marginValueUsd = bound({ x: marginValueUsd, min: USDC_MIN_DEPOSIT_MARGIN, max: USDC_DEPOSIT_CAP });

        feeAmount = bound({ x: feeAmount, min: USDC_MIN_DEPOSIT_MARGIN - 1, max: USDC_DEPOSIT_CAP - 1 });
        randomFeeAmount1 = bound({ x: feeAmount, min: USDC_MIN_DEPOSIT_MARGIN - 1, max: USDC_DEPOSIT_CAP - 1 });
        randomFeeAmount2 = bound({ x: feeAmount, min: USDC_MIN_DEPOSIT_MARGIN - 1, max: USDC_DEPOSIT_CAP - 1 });

        deal({ token: address(usdc), to: users.naruto, give: marginValueUsd });

        uint128 tradingAccountId = createAccountAndDeposit(marginValueUsd, address(usdc));

        FillOrderContext memory ctx;

        ctx.settlementFeeUsdX18 = ud60x18(randomFeeAmount1);

        UD60x18 pnlUsdX18 = ud60x18(randomFeeAmount2);

        UD60x18 orderFeeUsdX18 = ud60x18(feeAmount);

        TradingAccountHarness(address(perpsEngine)).exposed_deductAccountMargin({
            tradingAccountId: tradingAccountId,
            feeRecipients: FeeRecipients.Data({
                marginCollateralRecipient: MSIG_ADDRESS,
                orderFeeRecipient: MSIG_ADDRESS,
                settlementFeeRecipient: MSIG_ADDRESS
            }),
            pnlUsdX18: pnlUsdX18,
            orderFeeUsdX18: orderFeeUsdX18,
            settlementFeeUsdX18: ctx.settlementFeeUsdX18
        });
    }

    function testFuzz_WhenPnlUsdX18IsGreaterThanZeroAndIfTheAlreadyDeductedPnLPnlDeductedUsdX18IsLessThanTheTotalPnlUsdX18IndicatingRemainingPnLToBeAccountedFor(
        uint256 marginValueUsd,
        uint256 feeAmount,
        uint256 randomFeeAmount1,
        uint256 randomFeeAmount2
    )
        external
        givenTheAccountHasAMarginBalanceOf0
        whenThereIsCollateralLiquidationPriority
    {
        // it should deduct the PnL from the account's margin balance
        // it should return isMissingMargin a boolean indicating whether there was insufficient margin to cover the
        // fee

        marginValueUsd = bound({ x: marginValueUsd, min: USDC_MIN_DEPOSIT_MARGIN, max: USDC_DEPOSIT_CAP });

        feeAmount = bound({ x: feeAmount, min: USDC_MIN_DEPOSIT_MARGIN - 1, max: USDC_DEPOSIT_CAP - 1 });
        randomFeeAmount1 = bound({ x: feeAmount, min: USDC_MIN_DEPOSIT_MARGIN - 1, max: USDC_DEPOSIT_CAP - 1 });
        randomFeeAmount2 = bound({ x: feeAmount, min: USDC_MIN_DEPOSIT_MARGIN - 1, max: USDC_DEPOSIT_CAP - 1 });

        deal({ token: address(usdc), to: users.naruto, give: marginValueUsd });

        uint128 tradingAccountId = createAccountAndDeposit(marginValueUsd, address(usdc));

        FillOrderContext memory ctx;

        ctx.settlementFeeUsdX18 = ud60x18(randomFeeAmount1);

        UD60x18 pnlUsdX18 = ud60x18(feeAmount);

        UD60x18 orderFeeUsdX18 = ud60x18(randomFeeAmount2);

        TradingAccountHarness(address(perpsEngine)).exposed_deductAccountMargin({
            tradingAccountId: tradingAccountId,
            feeRecipients: FeeRecipients.Data({
                marginCollateralRecipient: MSIG_ADDRESS,
                orderFeeRecipient: MSIG_ADDRESS,
                settlementFeeRecipient: MSIG_ADDRESS
            }),
            pnlUsdX18: pnlUsdX18,
            orderFeeUsdX18: orderFeeUsdX18,
            settlementFeeUsdX18: ctx.settlementFeeUsdX18
        });
    }

    function testFuzz_WhenThereIsNotCollateralLiquidationPriority(
        uint256 marginValueUsd,
        uint256 feeAmount,
        uint256 randomFeeAmount1,
        uint256 randomFeeAmount2
    )
        external
    {
        // it should calculate the total margin deducted in USD (by summing up three different types of deductions
        // from an account's margin balance)
        // it should return the new margin balance
        address[] memory collateralTypes;

        perpsEngine.exposed_configureCollateralLiquidationPriority(collateralTypes);

        marginValueUsd = bound({ x: marginValueUsd, min: USDC_MIN_DEPOSIT_MARGIN, max: USDC_DEPOSIT_CAP });

        feeAmount = bound({ x: feeAmount, min: USDC_MIN_DEPOSIT_MARGIN - 1, max: USDC_DEPOSIT_CAP - 1 });
        randomFeeAmount1 = bound({ x: feeAmount, min: USDC_MIN_DEPOSIT_MARGIN - 1, max: USDC_DEPOSIT_CAP - 1 });
        randomFeeAmount2 = bound({ x: feeAmount, min: USDC_MIN_DEPOSIT_MARGIN - 1, max: USDC_DEPOSIT_CAP - 1 });

        deal({ token: address(usdc), to: users.naruto, give: marginValueUsd });

        uint128 tradingAccountId = createAccountAndDeposit(marginValueUsd, address(usdc));

        FillOrderContext memory ctx;

        ctx.settlementFeeUsdX18 = ud60x18(randomFeeAmount1);

        UD60x18 pnlUsdX18 = ud60x18(feeAmount);

        UD60x18 orderFeeUsdX18 = ud60x18(randomFeeAmount2);

        TradingAccountHarness(address(perpsEngine)).exposed_deductAccountMargin({
            tradingAccountId: tradingAccountId,
            feeRecipients: FeeRecipients.Data({
                marginCollateralRecipient: MSIG_ADDRESS,
                orderFeeRecipient: MSIG_ADDRESS,
                settlementFeeRecipient: MSIG_ADDRESS
            }),
            pnlUsdX18: pnlUsdX18,
            orderFeeUsdX18: orderFeeUsdX18,
            settlementFeeUsdX18: ctx.settlementFeeUsdX18
        });
    }
}
