// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { MockUniswapRouter } from "test/mocks/MockUniswapRouter.sol";
import { FeeDistributionBranch } from "@zaros/market-making/branches/FeeDistributionBranch.sol";
import { MockPriceFeed } from "test/mocks/MockPriceFeed.sol";

// Openzeppelin dependencies
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";

// UniSwap dependencies
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

contract ConvertAccumulatedFeesToWeth_Integration_Test is Base_Test {
    using EnumerableSet for EnumerableSet.UintSet;

    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        createVaults(marketMakingEngine, INITIAL_VAULT_ID, FINAL_VAULT_ID);
        configureMarketsDebt();
    }

    function testFuzz_RevertGiven_TheSenderIsNotRegisteredEngine(
        uint256 marketDebtId,
        uint128 dexSwapStrategyId
    )
        external
    {
        changePrank({ msgSender: users.naruto.account });

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.Unauthorized.selector, users.naruto.account) });

        marketMakingEngine.convertAccumulatedFeesToWeth(uint128(marketDebtId), address(usdc), dexSwapStrategyId);
    }

    modifier givenTheSenderIsRegisteredEngine() {
        _;
    }

    function testFuzz_RevertWhen_TheMarketDoesNotExist(
        uint128 dexSwapStrategyId
    )
        external
        givenTheSenderIsRegisteredEngine
    {
        changePrank({ msgSender: address(perpsEngine) });

        uint128 invalidMarketDebtId = FINAL_MARKET_DEBT_ID + 1;

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.UnrecognisedMarket.selector, invalidMarketDebtId) });

        marketMakingEngine.convertAccumulatedFeesToWeth(invalidMarketDebtId, address(usdc), dexSwapStrategyId);
    }

    modifier whenTheMarketExist() {
        _;
    }

    function testFuzz_RevertWhen_TheCollatealIsNotEnabled(
        uint256 marketDebtId,
        uint128 dexSwapStrategyId
    )
        external
        givenTheSenderIsRegisteredEngine
        whenTheMarketExist
    {
        changePrank({ msgSender: address(perpsEngine) });

        MarketDebtConfig memory fuzzMarketDebtConfig = getFuzzMarketDebtConfig(marketDebtId);

        address assetNotEnabled = address(0x123);

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.CollateralDisabled.selector, address(0)) });

        marketMakingEngine.convertAccumulatedFeesToWeth(
            fuzzMarketDebtConfig.marketDebtId, assetNotEnabled, dexSwapStrategyId
        );
    }

    modifier whenTheCollateralIsEnabled() {
        _;
    }

    function testFuzz_RevertWhen_TheMarketDebtDoesntHaveTheAsset(
        uint256 marketDebtId,
        uint128 dexSwapStrategyId
    )
        external
        givenTheSenderIsRegisteredEngine
        whenTheMarketExist
        whenTheCollateralIsEnabled
    {
        changePrank({ msgSender: address(perpsEngine) });

        MarketDebtConfig memory fuzzMarketDebtConfig = getFuzzMarketDebtConfig(marketDebtId);

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Errors.MarketDebtDoesNotContainTheAsset.selector, address(usdc))
        });

        marketMakingEngine.convertAccumulatedFeesToWeth(
            fuzzMarketDebtConfig.marketDebtId, address(usdc), dexSwapStrategyId
        );
    }

    modifier whenTheMarketDebtHasTheAsset() {
        _;
    }

    function testFuzz_RevertWhen_TheAmountIsZero(
        uint256 marketDebtId,
        uint128 dexSwapStrategyId
    )
        external
        givenTheSenderIsRegisteredEngine
        whenTheMarketExist
        whenTheCollateralIsEnabled
        whenTheMarketDebtHasTheAsset
    {
        changePrank({ msgSender: address(perpsEngine) });

        MarketDebtConfig memory fuzzMarketDebtConfig = getFuzzMarketDebtConfig(marketDebtId);

        marketMakingEngine.workaround_setReceivedMarketFees(fuzzMarketDebtConfig.marketDebtId, address(usdc), 0);

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.AssetAmountIsZero.selector, address(usdc)) });

        marketMakingEngine.convertAccumulatedFeesToWeth(
            fuzzMarketDebtConfig.marketDebtId, address(usdc), dexSwapStrategyId
        );
    }

    // function testFuzz_WhenTheAssetIsWeth(
    //     uint256 amountToReceive
    // )
    //     external
    //     givenTheCallerIsMarketMakingEngine
    //     whenMarketExist
    //     whenTheAmountIsNotZero
    //     whenTheAssetExists
    // {
    //     // amountToReceive = bound({ x: amountToReceive, min: WETH_MIN_DEPOSIT_MARGIN, max:
    //     // WETH_DEPOSIT_CAP_X18.intoUint256() });

    //     // // set contract with initial wEth fees
    //     // receiveOrderFeeInFeeDistribution(address(wEth), amountToReceive);

    //     // // it should emit event { LogConvertAccumulatedFeesToWeth }
    //     // vm.expectEmit();
    //     // emit FeeDistributionBranch.LogConvertAccumulatedFeesToWeth(
    //     //     address(wEth), amountToReceive, amountToReceive
    //     // );

    //     // marketMakingEngine.convertAccumulatedFeesToWeth(INITIAL_MARKET_DEBT_ID, address(wEth), 1);

    //     // uint256 feeRecipientsFees = marketMakingEngine.workaround_getFeeRecipientsFees(INITIAL_MARKET_DEBT_ID);

    //     // (uint128 marketPercentage, uint128 feeRecipientsPercentage) =
    //     // marketMakingEngine.getPercentageRatio(INITIAL_MARKET_DEBT_ID);

    //     // // it should divide amount between market and fee recipients
    //     // assertEq(feeRecipientsFees, (amountToReceive * feeRecipientsPercentage) / SwapRouter.BPS_DENOMINATOR);
    // }

    // modifier whenTheAssetIsNotWeth() {
    //     _;
    // }

    // function test_RevertGiven_PriceAdapterAddressIsNotSet(
    //     uint256 amountToReceive
    // )
    //     external
    //     givenTheCallerIsMarketMakingEngine
    //     whenMarketExist
    //     whenTheAmountIsNotZero
    //     whenTheAssetExists
    //     whenTheAssetIsNotWeth
    // {
    //     // amountToReceive =
    //     //     bound({ x: amountToReceive, min: WETH_MIN_DEPOSIT_MARGIN, max: WETH_DEPOSIT_CAP_X18.intoUint256()
    // });

    //     // // Deploy MockUniswapRouter to simulate the swap and mock
    //     // ISwapRouter swapRouter = ISwapRouter(address(new MockUniswapRouter()));
    //     // marketMakingEngine.exposed_setSwapStrategy(0, address(swapRouter));

    //     // // set contract with initial wbtc fees
    //     // receiveOrderFeeInFeeDistribution(address(wBtc), amountToReceive);

    //     // // Set Price Adapter address to zero
    //     // marketMakingEngine.workaround_Collateral_setParams(
    //     //     address(wBtc),
    //     //     WBTC_CORE_VAULT_CREDIT_RATIO,
    //     //     WBTC_PRICE_FEED_HEARBEAT_SECONDS,
    //     //     WBTC_CORE_VAULT_IS_ENABLED,
    //     //     WBTC_DECIMALS,
    //     //     address(0)
    //     // );

    //     // // it should revert
    //     // vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.PriceAdapterUndefined.selector) });
    //     // marketMakingEngine.convertAccumulatedFeesToWeth(INITIAL_MARKET_DEBT_ID, address(wBtc), 0);
    // }

    // modifier givenPriceAdapterAddressIsSet() {
    //     _;
    // }

    // function test_RevertGiven_TheUniswapAddressIsNotSet(
    //     uint256 amountToReceive
    // )
    //     external
    //     givenTheCallerIsMarketMakingEngine
    //     whenMarketExist
    //     whenTheAmountIsNotZero
    //     whenTheAssetExists
    //     whenTheAssetIsNotWeth
    //     givenPriceAdapterAddressIsSet
    // {
    //     // amountToReceive =
    //     //     bound({ x: amountToReceive, min: WETH_MIN_DEPOSIT_MARGIN, max: WETH_DEPOSIT_CAP_X18.intoUint256()
    // });

    //     // // set contract with initial wbtc fees
    //     // receiveOrderFeeInFeeDistribution(address(wBtc), amountToReceive);

    //     // // it should revert
    //     // vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "swapRouter address")
    // });
    //     // marketMakingEngine.convertAccumulatedFeesToWeth(INITIAL_MARKET_DEBT_ID, address(wBtc), 0);
    // }

    // modifier givenTheUniswapAddressIsSet() {
    //     _;
    // }

    // function testFuzz_GivenTokenInDecimalsAreLessThan18(
    //     uint256 amountToReceive
    // )
    //     external
    //     givenTheCallerIsMarketMakingEngine
    //     whenMarketExist
    //     whenTheAmountIsNotZero
    //     whenTheAssetExists
    //     whenTheAssetIsNotWeth
    //     givenPriceAdapterAddressIsSet
    //     givenTheUniswapAddressIsSet
    // {
    //     // amountToReceive = bound({ x: amountToReceive, min: WETH_MIN_DEPOSIT_MARGIN, max:
    //     // WETH_DEPOSIT_CAP_X18.intoUint256() });

    //     // // set contract with initial wbtc fees
    //     // receiveOrderFeeInFeeDistribution(address(wBtc), amountToReceive);

    //     // // Deploy MockUniswapRouter to simulate the swap and mock
    //     // ISwapRouter swapRouter = ISwapRouter(address(new MockUniswapRouter()));
    //     // marketMakingEngine.exposed_setSwapStrategy(0, address(swapRouter));

    //     // // Expect event emitted for fee conversion
    //     // vm.expectEmit();
    //     // emit FeeDistributionBranch.LogConvertAccumulatedFeesToWeth(address(wBtc), amountToReceive,
    //     // amountToReceive);

    //     // // Call the function to convert accumulated fees to WETH from wBtc (token with less than 18 decimals)
    //     // marketMakingEngine.convertAccumulatedFeesToWeth(INITIAL_MARKET_DEBT_ID, address(wBtc), 0);

    //     // // Check the resulting split of fees between market and fee recipients
    //     // uint256 feeRecipientsFees = marketMakingEngine.workaround_getFeeRecipientsFees(INITIAL_MARKET_DEBT_ID);

    //     // (uint128 marketPercentage, uint128 feeRecipientsPercentage) =
    //     // marketMakingEngine.getPercentageRatio(INITIAL_MARKET_DEBT_ID);

    //     // // it should divide amount between market and fee recipients
    //     // assertEq(feeRecipientsFees, (amountToReceive * feeRecipientsPercentage) / SwapRouter.BPS_DENOMINATOR);
    // }

    // function testFuzz_GivenTokenInDecimalsAre18(
    //     uint256 amountToReceive
    // )
    //     external
    //     givenTheCallerIsMarketMakingEngine
    //     whenMarketExist
    //     whenTheAmountIsNotZero
    //     whenTheAssetExists
    //     whenTheAssetIsNotWeth
    //     givenPriceAdapterAddressIsSet
    //     givenTheUniswapAddressIsSet
    // {
    //     // amountToReceive = bound({ x: amountToReceive, min: WETH_MIN_DEPOSIT_MARGIN, max:
    //     // WETH_DEPOSIT_CAP_X18.intoUint256() });

    //     // // set contract with initial usdc fees
    //     // receiveOrderFeeInFeeDistribution(address(usdc), amountToReceive);

    //     // // Deploy MockUniswapRouter to simulate the swap and mock
    //     // ISwapRouter swapRouter = ISwapRouter(address(new MockUniswapRouter()));
    //     // marketMakingEngine.exposed_setSwapStrategy(0, address(swapRouter));

    //     // // Expect event emitted for fee conversion
    //     // vm.expectEmit();
    //     // emit FeeDistributionBranch.LogConvertAccumulatedFeesToWeth(address(usdc), amountToReceive,
    //     // amountToReceive);

    //     // // Call the function to convert accumulated fees to WETH from usdc (token with 18 decimalsa)
    //     // marketMakingEngine.convertAccumulatedFeesToWeth(INITIAL_MARKET_DEBT_ID, address(usdc), 0);

    //     // // Check the resulting split of fees between market and fee recipients
    //     // uint256 feeRecipientsFees = marketMakingEngine.workaround_getFeeRecipientsFees(INITIAL_MARKET_DEBT_ID);

    //     // (uint128 marketPercentage, uint128 feeRecipientsPercentage) =
    //     // marketMakingEngine.getPercentageRatio(INITIAL_MARKET_DEBT_ID);

    //     // // it should divide amount between market and fee recipients
    //     // assertEq(feeRecipientsFees, (amountToReceive * feeRecipientsPercentage) / SwapRouter.BPS_DENOMINATOR);
    // }

    // function testFuzz_GivenTokenInDecimalsAreMoreThan18(
    //     uint256 amountToReceive
    // )
    //     external
    //     givenTheCallerIsMarketMakingEngine
    //     whenMarketExist
    //     whenTheAmountIsNotZero
    //     whenTheAssetExists
    //     whenTheAssetIsNotWeth
    //     givenPriceAdapterAddressIsSet
    //     givenTheUniswapAddressIsSet
    // {
    //     amountToReceive =
    //         bound({ x: amountToReceive, min: WETH_MIN_DEPOSIT_MARGIN, max: WETH_DEPOSIT_CAP_X18.intoUint256() });

    //     uint8 priceFeedDecimals = 8;
    //     int256 priceFeedPrice = 1e18;

    //     MockPriceFeed usdzMockPriceFeed = new MockPriceFeed(priceFeedDecimals, priceFeedPrice);

    //     uint8 tokenDecimals = 20;

    //     // Set tokenIn decimals to 20
    //     marketMakingEngine.workaround_Collateral_setParams(
    //         address(usdz),
    //         WBTC_CORE_VAULT_CREDIT_RATIO,
    //         WBTC_CORE_VAULT_IS_ENABLED,
    //         tokenDecimals,
    //         address(usdzMockPriceFeed)
    //     );

    //     // // set contract with initial usdc fees
    //     // receiveOrderFeeInFeeDistribution(address(usdz), amountToReceive);

    //     // // Deploy MockUniswapRouter to simulate the swap and mock
    //     // ISwapRouter swapRouter = ISwapRouter(address(new MockUniswapRouter()));
    //     // marketMakingEngine.exposed_setSwapStrategy(0, address(swapRouter));

    //     // // Expect event emitted for fee conversion
    //     // vm.expectEmit();
    //     // emit FeeDistributionBranch.LogConvertAccumulatedFeesToWeth(address(usdz), amountToReceive,
    //     // amountToReceive);

    //     // // Call the function to convert accumulated fees to WETH from usdz (token with 18 decimals)
    //     // marketMakingEngine.convertAccumulatedFeesToWeth(INITIAL_MARKET_DEBT_ID, address(usdz), 0);

    //     // // Check the resulting split of fees between market and fee recipients
    //     // uint256 feeRecipientsFees = marketMakingEngine.workaround_getFeeRecipientsFees(INITIAL_MARKET_DEBT_ID);

    //     // (uint128 marketPercentage, uint128 feeRecipientsPercentage) =
    //     // marketMakingEngine.getPercentageRatio(INITIAL_MARKET_DEBT_ID);

    //     // // it should divide amount between market and fee recipients
    //     // assertEq(feeRecipientsFees, (amountToReceive * feeRecipientsPercentage) / SwapRouter.BPS_DENOMINATOR);
    // }
}
