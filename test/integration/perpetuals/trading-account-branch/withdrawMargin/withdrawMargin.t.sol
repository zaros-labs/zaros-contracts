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

    // TODO: fix pnl issue on settle tests
    function testFuzz_RevertGiven_TheAccountWontMeetTheMarginRequirement(
        uint256 amountToDeposit,
        uint256 amountToWithdraw,
        uint256 marginRequirement,
        bool isLong,
        uint256 marketId
    )
        external
        givenTheAccountExists
        givenTheSenderIsAuthorized
        whenTheAmountIsNotZero
        givenThereIsEnoughMarginCollateral
    {
        // MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);
        // {
        //     amountToDeposit = bound({ x: amountToDeposit, min: USDZ_MIN_DEPOSIT_MARGIN, max: USDZ_DEPOSIT_CAP });
        //     marginRequirement = bound({
        //         x: marginRequirement,
        //         min: fuzzMarketConfig.imr,
        //         max: MAX_MARGIN_REQUIREMENTS
        //     });
        //     // TODO: discount order fees
        //     uint256 requiredMarginUsd = ud60x18(amountToDeposit).div(ud60x18(marginRequirement)).mul(
        //         ud60x18(fuzzMarketConfig.imr)
        //     ).intoUint256();
        //     amountToWithdraw = bound({ x: amountToWithdraw, min: requiredMarginUsd, max: amountToDeposit });
        //     deal({ token: address(usdToken), to: users.naruto, give: amountToDeposit });
        // }

        // uint128 tradingAccountId = createAccountAndDeposit(amountToDeposit, address(usdToken));
        // int128 sizeDelta = fuzzOrderSizeDelta(
        //     FuzzOrderSizeDeltaParams({
        //         tradingAccountId: tradingAccountId,
        //         marketId: fuzzMarketConfig.marketId,
        //         settlementConfigurationId: SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID,
        //         initialMarginRate: ud60x18(marginRequirement),
        //         marginValueUsd: ud60x18(amountToDeposit),
        //         maxOpenInterest: ud60x18(fuzzMarketConfig.maxOi),
        // maxSkew: ud60x18(fuzzMarketConfig.maxSkew),
        //         minTradeSize: ud60x18(fuzzMarketConfig.minTradeSize),
        //         price: ud60x18(fuzzMarketConfig.mockUsdPrice),
        //         isLong: isLong,
        //         shouldDiscountFees: true
        //     })
        // );
        // (SD59x18 marginBalanceUsdX18, UD60x18 requiredInitialMarginUsdX18, UD60x18
        // requiredMaintenanceMarginUsdX18,,,)
        // = perpsEngine.simulateTrade(
        //     tradingAccountId,
        //     fuzzMarketConfig.marketId,
        //     SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID,
        //     sizeDelta
        // );

        // perpsEngine.createMarketOrder(
        //     OrderBranch.CreateMarketOrderParams({
        //         tradingAccountId: tradingAccountId,
        //         marketId: fuzzMarketConfig.marketId,
        //         sizeDelta: sizeDelta
        //     })
        // );

        // changePrank({ msgSender: marketOrderKeepers[fuzzMarketConfig.marketId] });
        // bytes memory mockSignedReport =
        //     getMockedSignedReport(fuzzMarketConfig.streamId, fuzzMarketConfig.mockUsdPrice);
        // address marketOrderKeeper = marketOrderKeepers[fuzzMarketConfig.marketId];

        // perpsEngine.fillMarketOrder(tradingAccountId, fuzzMarketConfig.marketId, marketOrderKeeper,
        // mockSignedReport);

        // changePrank({ msgSender: users.naruto });

        // console.log("from wmt: ");
        // console.log(marginBalanceUsdX18.abs().intoUint256());
        // console.log(amountToWithdraw);
        // console.log(requiredInitialMarginUsdX18.add(requiredMaintenanceMarginUsdX18).intoUint256());

        // vm.expectRevert({
        //     revertData: abi.encodeWithSelector(
        //         Errors.InsufficientMargin.selector,
        //         tradingAccountId,
        //         marginBalanceUsdX18.intoInt256() - int256(amountToWithdraw),
        //         requiredInitialMarginUsdX18.add(requiredMaintenanceMarginUsdX18).intoUint256(),
        //         int256(0)
        //         )
        // });
        // // it should revert
        // perpsEngine.withdrawMargin(tradingAccountId, address(usdToken), ud60x18(amountToWithdraw));
    }

    function testFuzz_GivenTheAccountMeetsTheMarginRequirement(
        uint256 amountToDeposit,
        uint256 amountToWithdraw
    )
        external
        givenTheAccountExists
        givenTheSenderIsAuthorized
        whenTheAmountIsNotZero
        givenThereIsEnoughMarginCollateral
    {
        amountToDeposit = bound({ x: amountToDeposit, min: 1, max: USDZ_DEPOSIT_CAP });
        amountToWithdraw = bound({ x: amountToWithdraw, min: 1, max: amountToDeposit });
        deal({ token: address(usdToken), to: users.naruto, give: amountToDeposit });

        uint128 tradingAccountId = createAccountAndDeposit(amountToDeposit, address(usdToken));

        // it should emit a {LogWithdrawMargin} event
        vm.expectEmit({ emitter: address(perpsEngine) });
        emit TradingAccountBranch.LogWithdrawMargin(
            users.naruto, tradingAccountId, address(usdToken), amountToWithdraw
        );

        // it should transfer the withdrawn amount to the sender
        expectCallToTransfer(usdToken, users.naruto, amountToWithdraw);
        perpsEngine.withdrawMargin(tradingAccountId, address(usdToken), amountToWithdraw);

        uint256 expectedMargin = amountToDeposit - amountToWithdraw;
        uint256 newMarginCollateralBalance =
            perpsEngine.getAccountMarginCollateralBalance(tradingAccountId, address(usdToken)).intoUint256();

        // it should decrease the margin collateral balance
        assertEq(expectedMargin, newMarginCollateralBalance, "withdrawMargin");
    }
}
