// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { Base_Integration_Shared_Test } from "test/integration/shared/BaseIntegration.t.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { IOrderModule } from "@zaros/markets/perps/interfaces/IOrderModule.sol";
import { SettlementConfiguration } from "@zaros/markets/perps/storage/SettlementConfiguration.sol";

// PRB Math dependencies
import { UD60x18, ud60x18, ZERO as UD_ZERO } from "@prb-math/UD60x18.sol";
import { SD59x18 } from "@prb-math/SD59x18.sol";

import "forge-std/console.sol";

contract WithdrawMargin_Integration_Test is Base_Integration_Shared_Test {
    function setUp() public override {
        Base_Integration_Shared_Test.setUp();
        changePrank({ msgSender: users.owner });
        configureSystemParameters();
        createMarkets();
        changePrank({ msgSender: users.naruto });
    }

    function testFuzz_RevertGiven_TheAccountDoesNotExist(uint128 perpsAccountId) external {
        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Errors.AccountNotFound.selector, perpsAccountId, users.naruto)
        });
        perpsEngine.withdrawMargin(perpsAccountId, address(usdToken), UD_ZERO);
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

        uint128 perpsAccountId = createAccountAndDeposit(amountToDeposit, address(usdToken));
        changePrank({ msgSender: users.sasuke });

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Errors.AccountPermissionDenied.selector, perpsAccountId, users.sasuke)
        });
        perpsEngine.withdrawMargin(perpsAccountId, address(usdToken), ud60x18(amountToWithdraw));
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

        uint128 perpsAccountId = createAccountAndDeposit(amountToDeposit, address(usdToken));

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "amount") });
        perpsEngine.withdrawMargin(perpsAccountId, address(usdToken), UD_ZERO);
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

        uint128 perpsAccountId = createAccountAndDeposit(amountToDeposit, address(usdToken));

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                Errors.InsufficientCollateralBalance.selector, amountToWithdraw, expectedMarginCollateralBalance
                )
        });
        perpsEngine.withdrawMargin(perpsAccountId, address(usdToken), ud60x18(amountToWithdraw));
    }

    modifier givenThereIsEnoughMarginCollateral() {
        _;
    }

    // TODO: fix pnl issue on settle tests
    function testFuzz_RevertGiven_TheAccountWontMeetTheMarginRequirements(
        uint256 amountToDeposit,
        uint256 amountToWithdraw,
        uint256 marginRequirement,
        bool isLong
    )
        external
        givenTheAccountExists
        givenTheSenderIsAuthorized
        whenTheAmountIsNotZero
        givenThereIsEnoughMarginCollateral
    {
        {
            amountToDeposit = bound({ x: amountToDeposit, min: USDZ_MIN_DEPOSIT_MARGIN, max: USDZ_DEPOSIT_CAP });
            marginRequirement =
                bound({ x: marginRequirement, min: ETH_USD_MARGIN_REQUIREMENTS, max: MAX_MARGIN_REQUIREMENTS });
            // TODO: discount order fees
            uint256 requiredMarginUsd = ud60x18(amountToDeposit).div(ud60x18(marginRequirement)).mul(
                ud60x18(ETH_USD_MARGIN_REQUIREMENTS)
            ).intoUint256();
            amountToWithdraw = bound({ x: amountToWithdraw, min: requiredMarginUsd, max: amountToDeposit });
            deal({ token: address(usdToken), to: users.naruto, give: amountToDeposit });
        }

        uint128 perpsAccountId = createAccountAndDeposit(amountToDeposit, address(usdToken));
        int128 sizeDelta = fuzzOrderSizeDelta(
            FuzzOrderSizeDeltaParams({
                accountId: perpsAccountId,
                marketId: ETH_USD_MARKET_ID,
                settlementId: SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID,
                initialMarginRate: ud60x18(marginRequirement),
                marginValueUsd: ud60x18(amountToDeposit),
                maxOpenInterest: ud60x18(ETH_USD_MAX_OI),
                minTradeSize: ud60x18(ETH_USD_MIN_TRADE_SIZE),
                price: ud60x18(MOCK_ETH_USD_PRICE),
                isLong: isLong,
                shouldDiscountFees: true
            })
        );
        (SD59x18 marginBalanceUsdX18, UD60x18 requiredInitialMarginUsdX18, UD60x18 requiredMaintenanceMarginUsdX18,,,)
        = perpsEngine.simulateTrade(
            perpsAccountId, ETH_USD_MARKET_ID, SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID, sizeDelta
        );

        perpsEngine.createMarketOrder(
            IOrderModule.CreateMarketOrderParams({
                accountId: perpsAccountId,
                marketId: ETH_USD_MARKET_ID,
                sizeDelta: sizeDelta,
                acceptablePrice: 0
            })
        );

        changePrank({ msgSender: marketOrderKeepers[ETH_USD_MARKET_ID] });
        bytes memory mockBasicSignedReport = getMockedSignedReport(MOCK_ETH_USD_STREAM_ID, MOCK_ETH_USD_PRICE, false);

        mockSettleMarketOrder(perpsAccountId, ETH_USD_MARKET_ID, mockBasicSignedReport);

        changePrank({ msgSender: users.naruto });

        console.log("from wmt: ");
        console.log(marginBalanceUsdX18.abs().intoUint256());
        console.log(amountToWithdraw);
        console.log(requiredInitialMarginUsdX18.add(requiredMaintenanceMarginUsdX18).intoUint256());

        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                Errors.InsufficientMargin.selector,
                perpsAccountId,
                marginBalanceUsdX18.intoInt256() - int256(amountToWithdraw),
                requiredInitialMarginUsdX18.add(requiredMaintenanceMarginUsdX18).intoUint256(),
                int256(0)
                )
        });
        // it should revert
        perpsEngine.withdrawMargin(perpsAccountId, address(usdToken), ud60x18(amountToWithdraw));
    }

    function testFuzz_GivenTheAccountMeetsTheMarginRequirements(
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

        uint128 perpsAccountId = createAccountAndDeposit(amountToDeposit, address(usdToken));

        // it should emit a {LogWithdrawMargin} event
        vm.expectEmit({ emitter: address(perpsEngine) });
        emit LogWithdrawMargin(users.naruto, perpsAccountId, address(usdToken), amountToWithdraw);

        // it should transfer the withdrawn amount to the sender
        expectCallToTransfer(usdToken, users.naruto, amountToWithdraw);
        perpsEngine.withdrawMargin(perpsAccountId, address(usdToken), ud60x18(amountToWithdraw));

        uint256 expectedMargin = amountToDeposit - amountToWithdraw;
        uint256 newMarginCollateralBalance =
            perpsEngine.getAccountMarginCollateralBalance(perpsAccountId, address(usdToken)).intoUint256();

        // it should decrease the margin collateral balance
        assertEq(expectedMargin, newMarginCollateralBalance, "withdrawMargin");
    }
}
