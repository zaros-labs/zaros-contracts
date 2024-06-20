// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { SettlementConfiguration } from "@zaros/perpetuals/leaves/SettlementConfiguration.sol";
import { Base_Test } from "test/Base.t.sol";

// Open Zeppelin dependencies
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

// PRB Math dependencies
import { UD60x18, ud60x18, UNIT as UD_UNIT } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18, unary } from "@prb-math/SD59x18.sol";

import { console } from "forge-std/console.sol";

contract SimulateTrade_Integration_Test is Base_Test {
    using SafeCast for int256;

    function setUp() public override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner });
        configureSystemParameters();

        createPerpMarkets();

        changePrank({ msgSender: users.naruto });
    }

    function testFuzz_RevertGiven_TheAccountIdDoesNotExist(
        uint128 tradingAccountId,
        int128 sizeDelta,
        uint128 marketId,
        uint128 settlementConfigurationId
    )
        external
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        // Expect revert
        vm.expectRevert(abi.encodeWithSelector(Errors.AccountNotFound.selector, tradingAccountId, users.naruto));

        // perps engine calls and it gets forwarded to the order branch?
        perpsEngine.simulateTrade(tradingAccountId, fuzzMarketConfig.marketId, settlementConfigurationId, sizeDelta);
    }

    modifier givenTheAccountIdExists() {
        _;
    }

    function testFuzz_RevertGiven_ThePerpIdDoesNotExist(
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        bool isLong,
        uint128 settlementConfigurationId
    )
        external
        givenTheAccountIdExists
    {
        // random value
        // TODO: Use vm random values
        uint256 marketId = 999_999_999_999;

        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        initialMarginRate = bound({ x: initialMarginRate, min: fuzzMarketConfig.imr, max: MAX_MARGIN_REQUIREMENTS });
        marginValueUsd = bound({ x: marginValueUsd, min: USDC_MIN_DEPOSIT_MARGIN, max: USDC_DEPOSIT_CAP });

        deal({ token: address(usdc), to: users.naruto, give: marginValueUsd });

        uint128 tradingAccountId = createAccountAndDeposit(marginValueUsd, address(usdc));
        int128 sizeDelta = fuzzOrderSizeDelta(
            FuzzOrderSizeDeltaParams({
                tradingAccountId: tradingAccountId,
                marketId: fuzzMarketConfig.marketId,
                settlementConfigurationId: SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID,
                initialMarginRate: ud60x18(initialMarginRate),
                marginValueUsd: ud60x18(marginValueUsd),
                maxSkew: ud60x18(fuzzMarketConfig.maxSkew),
                minTradeSize: ud60x18(fuzzMarketConfig.minTradeSize),
                price: ud60x18(fuzzMarketConfig.mockUsdPrice),
                isLong: isLong,
                shouldDiscountFees: true
            })
        );

        changePrank({ msgSender: users.owner });
        perpsEngine.updatePerpMarketStatus({ marketId: fuzzMarketConfig.marketId, enable: false });

        changePrank({ msgSender: users.naruto });

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Errors.PerpMarketDisabled.selector, fuzzMarketConfig.marketId)
        });

        perpsEngine.simulateTrade(tradingAccountId, fuzzMarketConfig.marketId, settlementConfigurationId, sizeDelta);
    }

    modifier givenThePerpMarketIdExists() {
        _;
    }

    function test_RevertWhen_TheSizeDeltaIsZero(
        uint256 marketId,
        uint128 settlementConfigurationId
    )
        external
        givenTheAccountIdExists
        givenThePerpMarketIdExists
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        uint128 tradingAccountId = perpsEngine.createTradingAccount();

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "sizeDelta") });

        // TODO: Cleanup unused vars after fixing test
        (
            SD59x18 marginBalanceUsdX18,
            UD60x18 requiredInitialMarginUsdX18,
            UD60x18 requiredMaintenanceMarginUsdX18,
            SD59x18 orderFeeUsdX18,
            UD60x18 settlementFeeUsdX18,
            UD60x18 fillPriceX18
        ) = perpsEngine.simulateTrade(tradingAccountId, fuzzMarketConfig.marketId, settlementConfigurationId, 0);

        // console.log(marginBalanceUsdX18);

        // console.logInt(requiredInitialMarginUsdX18);

        // console.logInt(requiredMaintenanceMarginUsdX18);

        // console.logInt(orderFeeUsdX18);

        // console.logInt(settlementFeeUsdX18);

        // console.logInt(fillPriceX18);
    }

    modifier givenTheSizeDeltaIsNotZero() {
        _;
    }

    function testFuzz_RevertWhen_ThereIsInsufficientLiquidity()
        external
        givenTheAccountIdExists
        givenThePerpMarketIdExists
        givenTheSizeDeltaIsNotZero
    {
        // mock unsifficient luqidity
    }

    modifier whenThereIsSufficientLiquidity() {
        _;
    }

    function testFuzz_RevertWhen_AccountIsLiquidatable()
        external
        givenTheAccountIdExists
        givenThePerpMarketIdExists
        givenTheSizeDeltaIsNotZero
        whenThereIsSufficientLiquidity
    {
        // mock UD60x18 requiredMaintenanceMarginUsdX18 > SD59x18 marginBalanceUsdX18
    }

    modifier whenAccountIsNotLiquidatable() {
        _;
    }

    function testFuzz_RevertWhen_PositionIsTooSmall()
        external
        givenTheAccountIdExists
        givenThePerpMarketIdExists
        givenTheSizeDeltaIsNotZero
        whenAccountIsNotLiquidatable
        whenThereIsSufficientLiquidity
    {
        // mock newPositionSizeX18 == 0
        // mock additional logic check -
        // newPositionSizeX18.abs().lt(sd59x18(int256(uint256(perpMarket.configuration.minTradeSizeX18))))
        // better to split the test in two pieces
    }

    modifier whenwPositionIsNotTooSmall() {
        _;
    }

    /// working test case
    function testFuzz_GivenThereIsNoPendingMarketOrder(
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        bool isLong,
        uint256 marketId
    )
        external
        givenTheAccountIdExists
        givenThePerpMarketIdExists
        givenTheSizeDeltaIsNotZero
        whenAccountIsNotLiquidatable
        whenThereIsSufficientLiquidity
        whenwPositionIsNotTooSmall
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        initialMarginRate = bound({ x: initialMarginRate, min: fuzzMarketConfig.imr, max: MAX_MARGIN_REQUIREMENTS });
        marginValueUsd = bound({ x: marginValueUsd, min: USDC_MIN_DEPOSIT_MARGIN, max: USDC_DEPOSIT_CAP });

        // give user usdc
        deal({ token: address(usdc), to: users.naruto, give: marginValueUsd });

        // create trading account
        uint128 tradingAccountId = createAccountAndDeposit(marginValueUsd, address(usdc));
        int128 sizeDelta = fuzzOrderSizeDelta(
            FuzzOrderSizeDeltaParams({
                tradingAccountId: tradingAccountId,
                marketId: fuzzMarketConfig.marketId,
                settlementConfigurationId: SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID,
                initialMarginRate: ud60x18(initialMarginRate),
                marginValueUsd: ud60x18(marginValueUsd),
                maxSkew: ud60x18(fuzzMarketConfig.maxSkew),
                minTradeSize: ud60x18(fuzzMarketConfig.minTradeSize),
                price: ud60x18(fuzzMarketConfig.mockUsdPrice),
                isLong: isLong,
                shouldDiscountFees: true
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
    }
}
