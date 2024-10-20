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
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.MarketDoesNotExist.selector, invalidMarketDebtId) });

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

        PerpMarketCreditConfig memory fuzzPerpMarketCreditConfig = getFuzzPerpMarketCreditConfig(marketDebtId);

        address assetNotEnabled = address(0x123);

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.CollateralDisabled.selector, address(0)) });

        marketMakingEngine.convertAccumulatedFeesToWeth(
            fuzzPerpMarketCreditConfig.marketDebtId, assetNotEnabled, dexSwapStrategyId
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

        PerpMarketCreditConfig memory fuzzPerpMarketCreditConfig = getFuzzPerpMarketCreditConfig(marketDebtId);

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Errors.MarketDebtDoesNotContainTheAsset.selector, address(usdc))
        });

        marketMakingEngine.convertAccumulatedFeesToWeth(
            fuzzPerpMarketCreditConfig.marketDebtId, address(usdc), dexSwapStrategyId
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

        PerpMarketCreditConfig memory fuzzPerpMarketCreditConfig = getFuzzPerpMarketCreditConfig(marketDebtId);

        marketMakingEngine.workaround_setReceivedMarketFees(fuzzPerpMarketCreditConfig.marketDebtId, address(usdc), 0);

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.AssetAmountIsZero.selector, address(usdc)) });

        marketMakingEngine.convertAccumulatedFeesToWeth(
            fuzzPerpMarketCreditConfig.marketDebtId, address(usdc), dexSwapStrategyId
        );
    }

    modifier whenTheAmountIsNotZero() {
        _;
    }

    function testFuzz_RevertWhen_TheDexSwapStrategyHasAnInvalidDexAdapter(
        uint256 marketDebtId,
        uint256 amount
    )
        external
        givenTheSenderIsRegisteredEngine
        whenTheMarketExist
        whenTheCollateralIsEnabled
        whenTheMarketDebtHasTheAsset
        whenTheAmountIsNotZero
    {
        changePrank({ msgSender: address(perpsEngine) });

        uint128 wrongStrategyId = 0;

        PerpMarketCreditConfig memory fuzzPerpMarketCreditConfig = getFuzzPerpMarketCreditConfig(marketDebtId);

        amount = bound({
            x: amount,
            min: USDC_MIN_DEPOSIT_MARGIN,
            max: convertUd60x18ToTokenAmount(address(usdc), USDC_DEPOSIT_CAP_X18)
        });

        deal({ token: address(usdc), to: address(perpsEngine), give: amount });

        marketMakingEngine.receiveMarketFee(fuzzPerpMarketCreditConfig.marketDebtId, address(usdc), amount);

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Errors.DexSwapStrategyHasAnInvalidDexAdapter.selector, wrongStrategyId)
        });

        marketMakingEngine.convertAccumulatedFeesToWeth(
            fuzzPerpMarketCreditConfig.marketDebtId, address(usdc), wrongStrategyId
        );
    }

    function testFuzz_WhenTheDexSwapStrategyHasAValidDexAdapter(
        uint256 marketDebtId,
        uint256 amount
    )
        external
        givenTheSenderIsRegisteredEngine
        whenTheMarketExist
        whenTheCollateralIsEnabled
        whenTheMarketDebtHasTheAsset
        whenTheAmountIsNotZero
    {
        changePrank({ msgSender: address(perpsEngine) });

        uint128 uniswapV3StrategyId = 1;

        PerpMarketCreditConfig memory fuzzPerpMarketCreditConfig = getFuzzPerpMarketCreditConfig(marketDebtId);

        amount = bound({
            x: amount,
            min: USDC_MIN_DEPOSIT_MARGIN,
            max: convertUd60x18ToTokenAmount(address(usdc), USDC_DEPOSIT_CAP_X18)
        });

        deal({ token: address(usdc), to: address(perpsEngine), give: amount });

        marketMakingEngine.receiveMarketFee(fuzzPerpMarketCreditConfig.marketDebtId, address(usdc), amount);

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
        emit FeeDistributionBranch.LogConvertAccumulatedFeesToWeth(address(usdc), amount, amountOutMin);

        marketMakingEngine.convertAccumulatedFeesToWeth(
            fuzzPerpMarketCreditConfig.marketDebtId, address(usdc), uniswapV3StrategyId
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
        UD60x18 expectedAvailableFeesToWithdrawX18 =
            amountOutMinX18.mul(ud60x18(fuzzPerpMarketCreditConfig.feeRecipientsShare));

        assertEq(
            marketMakingEngine.workaround_getAvailableFeesToWithdraw(fuzzPerpMarketCreditConfig.marketDebtId),
            expectedAvailableFeesToWithdrawX18.intoUint256(),
            "the available fees to withdraw is wrong"
        );

        // TODO
        // it should distribute value to the vault

        // TODO
        // it should remove the asset from receivedMarketFees
    }
}
