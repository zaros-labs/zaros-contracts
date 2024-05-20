// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Integration_Shared_Test } from "test/integration/shared/BaseIntegration.t.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { OrderBranch } from "@zaros/perpetuals/branches/OrderBranch.sol";
import { SettlementConfiguration } from "@zaros/perpetuals/leaves/SettlementConfiguration.sol";
import { TradingAccountBranch } from "@zaros/perpetuals/branches/TradingAccountBranch.sol";

// PRB Math dependencies
import { UD60x18, ud60x18, ZERO as UD_ZERO } from "@prb-math/UD60x18.sol";
import { SD59x18 } from "@prb-math/SD59x18.sol";

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
        perpsEngine.withdrawMargin(tradingAccountId, address(usdToken), UD_ZERO);
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
        perpsEngine.withdrawMargin(tradingAccountId, address(usdToken), ud60x18(amountToWithdraw));
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
        perpsEngine.withdrawMargin(tradingAccountId, address(usdToken), UD_ZERO);
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
        perpsEngine.withdrawMargin(tradingAccountId, address(usdToken), ud60x18(amountToWithdraw));
    }

    modifier givenThereIsEnoughMarginCollateral() {
        _;
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
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        // avoids very small rounding errors in super edge cases
        UD60x18 adjustedMarginRequirements = ud60x18(fuzzMarketConfig.imr).mul(ud60x18(1.001e18));
        UD60x18 maxMarginValueUsd = adjustedMarginRequirements.mul(ud60x18(fuzzMarketConfig.maxSkew)).mul(
            ud60x18(fuzzMarketConfig.mockUsdPrice)
        );

        marginValueUsd =
            bound({ x: marginValueUsd, min: USDZ_MIN_DEPOSIT_MARGIN, max: maxMarginValueUsd.intoUint256() });
        amountToWithdraw = bound({ x: amountToWithdraw, min: USDZ_MIN_DEPOSIT_MARGIN, max: marginValueUsd });

        deal({ token: address(usdToken), to: users.naruto, give: marginValueUsd });

        uint128 tradingAccountId = createAccountAndDeposit(marginValueUsd, address(usdToken));
        int128 sizeDelta = fuzzOrderSizeDelta(
            FuzzOrderSizeDeltaParams({
                tradingAccountId: tradingAccountId,
                marketId: fuzzMarketConfig.marketId,
                settlementConfigurationId: SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID,
                initialMarginRate: adjustedMarginRequirements,
                marginValueUsd: ud60x18(marginValueUsd),
                maxSkew: ud60x18(fuzzMarketConfig.maxSkew),
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

        (
            SD59x18 marginBalanceUsdX18,
            UD60x18 requiredInitialMarginUsdX18,
            ,
            SD59x18 orderFeeUsdX18,
            UD60x18 settlementFeeUsdX18,
        ) = perpsEngine.simulateTrade(
            tradingAccountId,
            fuzzMarketConfig.marketId,
            SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID,
            sizeDelta
        );

        int256 newMarginBalanceUsd = marginBalanceUsdX18.intoInt256() - int256(amountToWithdraw);

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                Errors.InsufficientMargin.selector,
                tradingAccountId,
                newMarginBalanceUsd,
                requiredInitialMarginUsdX18,
                sd59x18(0)
            )
        });
        perpsEngine.withdrawMargin({
            tradingAccountId: tradingAccountId,
            collateralType: address(usdToken),
            amount: amountToWithdraw
        });
    }
}
