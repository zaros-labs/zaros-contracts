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

import { Position } from "@zaros/perpetuals/leaves/Position.sol";

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
        uint256[2] memory marketsIdsRange;
        marketsIdsRange[0] = 15;
        marketsIdsRange[1] = 20;

        MarketConfig[] memory wrongFilteredMarketsConfig = getFilteredMarketsConfig(marketsIdsRange);
        MarketConfig memory unFilteredMarketsConfig = wrongFilteredMarketsConfig[0];

        initialMarginRate =
            bound({ x: initialMarginRate, min: unFilteredMarketsConfig.imr, max: MAX_MARGIN_REQUIREMENTS });
        marginValueUsd = bound({ x: marginValueUsd, min: USDC_MIN_DEPOSIT_MARGIN, max: USDC_DEPOSIT_CAP });

        deal({ token: address(usdc), to: users.naruto, give: marginValueUsd });

        uint128 tradingAccountId = createAccountAndDeposit(marginValueUsd, address(usdc));

        int128 sizeDelta = 10_000;

        vm.startPrank(users.naruto);

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.PriceAdapterNotDefined.selector, 0) });

        perpsEngine.simulateTrade(
            tradingAccountId, unFilteredMarketsConfig.marketId, settlementConfigurationId, sizeDelta
        );

        vm.stopPrank();
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
        /// @dev this test is commented until checks logic is moved into simulateTrade function

        // MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        // uint128 tradingAccountId = perpsEngine.createTradingAccount();

        // // it should revert
        // vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "sizeDelta") });

        // // TODO: Cleanup unused vars after fixing test
        // (
        //     SD59x18 marginBalanceUsdX18,
        //     UD60x18 requiredInitialMarginUsdX18,
        //     UD60x18 requiredMaintenanceMarginUsdX18,
        //     SD59x18 orderFeeUsdX18,
        //     UD60x18 settlementFeeUsdX18,
        //     UD60x18 fillPriceX18
        // ) = perpsEngine.simulateTrade(tradingAccountId, fuzzMarketConfig.marketId, settlementConfigurationId, 0);

        // console.log(marginBalanceUsdX18);

        // console.logInt(requiredInitialMarginUsdX18);

        // console.logInt(requiredMaintenanceMarginUsdX18);

        // console.logInt(orderFeeUsdX18);

        // console.logInt(settlementFeeUsdX18);

        // console.logInt(fillPriceX18);
    }

    modifier whenTheSizeDeltaIsNotZero() {
        _;
    }

    function testFuzz_RevertWhen_ThereIsInsufficientLiquidity()
        external
        givenTheAccountIdExists
        givenThePerpMarketIdExists
        whenTheSizeDeltaIsNotZero
    {
        /// @dev this test will be added when the audit issue with checks in simulateTrade is resolved
        // mock unsifficient luqidity
    }

    modifier whenThereIsSufficientLiquidity() {
        _;
    }

    function testFuzz_RevertWhen_AccountIsLiquidatable(
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        bool isLong,
        uint256 marketId
    )
        external
        givenTheAccountIdExists
        givenThePerpMarketIdExists
        whenTheSizeDeltaIsNotZero
        whenThereIsSufficientLiquidity
    {
        /// @dev check this once again
        // MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        // initialMarginRate = bound({ x: initialMarginRate, min: fuzzMarketConfig.imr, max: MAX_MARGIN_REQUIREMENTS
        // });
        // marginValueUsd = bound({ x: marginValueUsd, min: USDC_MIN_DEPOSIT_MARGIN, max: USDC_DEPOSIT_CAP });

        // // give user usdc
        // deal({ token: address(usdc), to: users.naruto, give: marginValueUsd });

        // // create trading account
        // uint128 tradingAccountId = createAccountAndDeposit(marginValueUsd, address(usdc));
        // int128 sizeDelta = fuzzOrderSizeDelta(
        //     FuzzOrderSizeDeltaParams({
        //         tradingAccountId: tradingAccountId,
        //         marketId: fuzzMarketConfig.marketId,
        //         settlementConfigurationId: SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID,
        //         initialMarginRate: ud60x18(initialMarginRate),
        //         marginValueUsd: ud60x18(marginValueUsd),
        //         maxSkew: ud60x18(fuzzMarketConfig.maxSkew),
        //         minTradeSize: ud60x18(fuzzMarketConfig.minTradeSize),
        //         price: ud60x18(fuzzMarketConfig.mockUsdPrice),
        //         isLong: isLong,
        //         shouldDiscountFees: true
        //     })
        // );

        // /// @dev open a positions first so the account is liquidatable?
        // // openPosition(fuzzMarketConfig, tradingAccountId, initialMarginRate, marginValueUsd, isLong);

        // /// @dev this does not revert?
        // setAccountsAsLiquidatable(fuzzMarketConfig, isLong);

        // vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.AccountIsLiquidatable.selector,
        // tradingAccountId) });

        // perpsEngine.simulateTrade(
        //     tradingAccountId,
        //     fuzzMarketConfig.marketId,
        //     SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID,
        //     sizeDelta
        // );
    }

    modifier whenAccountIsNotLiquidatable() {
        _;
    }

    function testFuzz_RevertWhen_PositionIsTooSmall(
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        uint128 marketId
    )
        external
        givenTheAccountIdExists
        givenThePerpMarketIdExists
        whenTheSizeDeltaIsNotZero
        whenAccountIsNotLiquidatable
        whenThereIsSufficientLiquidity
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);
        initialMarginRate = bound({ x: initialMarginRate, min: fuzzMarketConfig.imr, max: MAX_MARGIN_REQUIREMENTS });
        marginValueUsd = bound({ x: marginValueUsd, min: USDC_MIN_DEPOSIT_MARGIN, max: USDC_DEPOSIT_CAP });

        deal({ token: address(usdc), to: users.naruto, give: marginValueUsd });

        uint128 tradingAccountId = createAccountAndDeposit(marginValueUsd, address(usdc));

        int128 sizeDelta = int128(fuzzMarketConfig.minTradeSize - 1);

        vm.startPrank(users.naruto);

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.NewPositionSizeTooSmall.selector) });

        perpsEngine.simulateTrade(
            tradingAccountId,
            fuzzMarketConfig.marketId,
            SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID,
            sizeDelta
        );

        vm.stopPrank();
    }

    modifier whenPositionIsNotTooSmall() {
        _;
    }

    function testFuzz_simulateTradeTest(
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        bool isLong,
        uint256 marketId
    )
        external
        givenTheAccountIdExists
        givenThePerpMarketIdExists
        whenTheSizeDeltaIsNotZero
        whenAccountIsNotLiquidatable
        whenThereIsSufficientLiquidity
        whenPositionIsNotTooSmall
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

        perpsEngine.simulateTrade(
            tradingAccountId,
            fuzzMarketConfig.marketId,
            SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID,
            sizeDelta
        );
    }
}
