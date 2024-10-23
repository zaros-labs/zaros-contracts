// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { FeeDistributionBranch } from "@zaros/market-making/branches/FeeDistributionBranch.sol";
import { UniswapV3Adapter } from "@zaros/utils/dex-adapters/UniswapV3Adapter.sol";
import { Math } from "@zaros/utils/Math.sol";

// Openzeppelin dependencies
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";
import { IERC20 } from "@openzeppelin/token/ERC20/extensions/ERC4626.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

contract ConvertAccumulatedFeesToWeth_Integration_Test is Base_Test {
    using EnumerableSet for EnumerableSet.UintSet;

    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        createVaults(marketMakingEngine, INITIAL_VAULT_ID, FINAL_VAULT_ID);
        configureMarkets();
    }

    function testFuzz_RevertGiven_TheSenderIsNotRegisteredEngine(
        uint256 marketId,
        uint128 dexSwapStrategyId
    )
        external
    {
        changePrank({ msgSender: users.naruto.account });

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.Unauthorized.selector, users.naruto.account) });

        marketMakingEngine.convertAccumulatedFeesToWeth(uint128(marketId), address(usdc), dexSwapStrategyId);
    }

    modifier givenTheSenderIsRegisteredEngine() {
        _;
    }

    function testFuzz_RevertWhen_TheMarketDoesNotExist(uint128 dexSwapStrategyId)
        external
        givenTheSenderIsRegisteredEngine
    {
        changePrank({ msgSender: address(perpsEngine) });

        uint128 invalidMarketId = FINAL_PERP_MARKET_CREDIT_CONFIG_ID + 1;

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.MarketDoesNotExist.selector, invalidMarketId) });

        marketMakingEngine.convertAccumulatedFeesToWeth(invalidMarketId, address(usdc), dexSwapStrategyId);
    }

    modifier whenTheMarketExist() {
        _;
    }

    function testFuzz_RevertWhen_TheCollatealIsNotEnabled(
        uint256 marketId,
        uint128 dexSwapStrategyId
    )
        external
        givenTheSenderIsRegisteredEngine
        whenTheMarketExist
    {
        changePrank({ msgSender: address(perpsEngine) });

        PerpMarketCreditConfig memory fuzzPerpMarketCreditConfig = getFuzzPerpMarketCreditConfig(marketId);

        address assetNotEnabled = address(0x123);

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.CollateralDisabled.selector, address(0)) });

        marketMakingEngine.convertAccumulatedFeesToWeth(
            fuzzPerpMarketCreditConfig.marketId, assetNotEnabled, dexSwapStrategyId
        );
    }

    modifier whenTheCollateralIsEnabled() {
        _;
    }

    function testFuzz_RevertWhen_TheMarketDoesntHaveTheAsset(
        uint256 marketId,
        uint128 dexSwapStrategyId
    )
        external
        givenTheSenderIsRegisteredEngine
        whenTheMarketExist
        whenTheCollateralIsEnabled
    {
        changePrank({ msgSender: address(perpsEngine) });

        PerpMarketCreditConfig memory fuzzPerpMarketCreditConfig = getFuzzPerpMarketCreditConfig(marketId);

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Errors.MarketDoesNotContainTheAsset.selector, address(usdc))
        });

        marketMakingEngine.convertAccumulatedFeesToWeth(
            fuzzPerpMarketCreditConfig.marketId, address(usdc), dexSwapStrategyId
        );
    }

    modifier whenTheMarketHasTheAsset() {
        _;
    }

    function testFuzz_RevertWhen_TheAmountIsZero(
        uint256 marketId,
        uint128 dexSwapStrategyId
    )
        external
        givenTheSenderIsRegisteredEngine
        whenTheMarketExist
        whenTheCollateralIsEnabled
        whenTheMarketHasTheAsset
    {
        changePrank({ msgSender: address(perpsEngine) });

        PerpMarketCreditConfig memory fuzzPerpMarketCreditConfig = getFuzzPerpMarketCreditConfig(marketId);

        marketMakingEngine.workaround_setReceivedMarketFees(fuzzPerpMarketCreditConfig.marketId, address(usdc), 0);

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.AssetAmountIsZero.selector, address(usdc)) });

        marketMakingEngine.convertAccumulatedFeesToWeth(
            fuzzPerpMarketCreditConfig.marketId, address(usdc), dexSwapStrategyId
        );
    }

    modifier whenTheAmountIsNotZero() {
        _;
    }

    function testFuzz_RevertWhen_TheDexSwapStrategyHasAnInvalidDexAdapter(
        uint256 marketId,
        uint256 amount
    )
        external
        givenTheSenderIsRegisteredEngine
        whenTheMarketExist
        whenTheCollateralIsEnabled
        whenTheMarketHasTheAsset
        whenTheAmountIsNotZero
    {
        changePrank({ msgSender: address(perpsEngine) });

        uint128 wrongStrategyId = 0;

        PerpMarketCreditConfig memory fuzzPerpMarketCreditConfig = getFuzzPerpMarketCreditConfig(marketId);

        amount = bound({
            x: amount,
            min: USDC_MIN_DEPOSIT_MARGIN,
            max: convertUd60x18ToTokenAmount(address(usdc), USDC_DEPOSIT_CAP_X18)
        });

        deal({ token: address(usdc), to: address(perpsEngine), give: amount });

        marketMakingEngine.receiveMarketFee(fuzzPerpMarketCreditConfig.marketId, address(usdc), amount);

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Errors.DexSwapStrategyHasAnInvalidDexAdapter.selector, wrongStrategyId)
        });

        marketMakingEngine.convertAccumulatedFeesToWeth(
            fuzzPerpMarketCreditConfig.marketId, address(usdc), wrongStrategyId
        );
    }

    function testFuzz_WhenTheDexSwapStrategyHasAValidDexAdapter(
        uint256 marketId,
        uint256 amount
    )
        external
        givenTheSenderIsRegisteredEngine
        whenTheMarketExist
        whenTheCollateralIsEnabled
        whenTheMarketHasTheAsset
        whenTheAmountIsNotZero
    {
        changePrank({ msgSender: address(perpsEngine) });

        uint128 uniswapV3StrategyId = 1;

        PerpMarketCreditConfig memory fuzzPerpMarketCreditConfig = getFuzzPerpMarketCreditConfig(marketId);

        amount = bound({
            x: amount,
            min: USDC_MIN_DEPOSIT_MARGIN,
            max: convertUd60x18ToTokenAmount(address(usdc), USDC_DEPOSIT_CAP_X18)
        });

        deal({ token: address(usdc), to: address(perpsEngine), give: amount });

        marketMakingEngine.receiveMarketFee(fuzzPerpMarketCreditConfig.marketId, address(usdc), amount);

        assertEq(
            IERC20(usdc).balanceOf(address(uniswapV3Adapter)),
            0,
            "the uniswap v3 adapter should have 0 balance of usdc"
        );
        assertEq(
            IERC20(wEth).balanceOf(address(uniswapV3Adapter)),
            0,
            "the uniswap v3 adapter should have 0 balance of wEth"
        );

        assertEq(IERC20(usdc).balanceOf(address(marketMakingEngine)), amount);
        assertEq(IERC20(wEth).balanceOf(address(marketMakingEngine)), 0);

        uint256 expectedTokenAmount = uniswapV3Adapter.getExpectedOutput(address(usdc), address(wEth), amount);
        uint256 amountOutMin = uniswapV3Adapter.calculateAmountOutMin(expectedTokenAmount);

        // it should emit {LogConvertAccumulatedFeesToWeth} event
        vm.expectEmit({ emitter: address(marketMakingEngine) });
        emit FeeDistributionBranch.LogConvertAccumulatedFeesToWeth(amountOutMin);

        marketMakingEngine.convertAccumulatedFeesToWeth(
            fuzzPerpMarketCreditConfig.marketId, address(usdc), uniswapV3StrategyId
        );

        // it should verify if the asset is different that weth and convert
        assertEq(
            IERC20(usdc).balanceOf(address(uniswapV3Adapter)),
            0,
            "the uniswap v3 adapter should have 0 balance of usdc"
        );
        assertEq(
            IERC20(wEth).balanceOf(address(uniswapV3Adapter)),
            0,
            "the uniswap v3 adapter should have 0 balance of wEth"
        );

        assertEq(
            IERC20(usdc).balanceOf(address(marketMakingEngine)),
            0,
            "the balance of the usdc in the market making engine after the convert should be zero"
        );
        assertEq(
            IERC20(wEth).balanceOf(address(marketMakingEngine)),
            amountOutMin,
            "the balance of the wEth in the market making engine after the convert is wrong"
        );

        // it should update the available fees to withdraw
        UD60x18 amountOutMinX18 = Math.convertTokenAmountToUd60x18(wEth.decimals(), amountOutMin);
        UD60x18 expectedPendingProtocolWethRewardX18 =
            amountOutMinX18.mul(marketMakingEngine.exposed_getTotalFeeRecipientsShares());

        assertEq(
            marketMakingEngine.workaround_getPendingProtocolWethReward(fuzzPerpMarketCreditConfig.marketId),
            expectedPendingProtocolWethRewardX18.intoUint256(),
            "the available fees to withdraw is wrong"
        );

        // TODO
        // it should distribute value to the vault

        // TODO
        // it should remove the asset from receivedMarketFees
    }
}
