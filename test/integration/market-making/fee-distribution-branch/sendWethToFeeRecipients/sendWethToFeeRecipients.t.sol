// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { FeeDistributionBranch } from "@zaros/market-making/branches/FeeDistributionBranch.sol";
import { Base_Test } from "test/Base.t.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { Math } from "@zaros/utils/Math.sol";

// Openzeppelin dependencies
import { IERC20 } from "@openzeppelin/token/ERC20/extensions/ERC4626.sol";
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";

// PRB Math dependencies
import { UD60x18, ud60x18, convert as convertToUd60x18 } from "@prb-math/UD60x18.sol";

contract SendWethToFeeRecipients_Integration_Test is Base_Test {
    using EnumerableSet for EnumerableSet.UintSet;

    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: address(users.owner.account) });
        configureMarkets();
    }

    function testFuzz_RevertGiven_TheSenderIsNotRegisteredEngine(uint256 marketId) external {
        changePrank({ msgSender: users.naruto.account });

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.Unauthorized.selector, users.naruto.account) });
        marketMakingEngine.sendWethToFeeRecipients(uint128(marketId));
    }

    modifier givenTheSenderIsRegisteredEngine() {
        _;
    }

    function test_RevertWhen_TheMarketDoesNotExist() external givenTheSenderIsRegisteredEngine {
        changePrank({ msgSender: address(perpsEngine) });

        uint128 invalidMarketId = FINAL_PERP_MARKET_CREDIT_CONFIG_ID + 1;

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.MarketDoesNotExist.selector, invalidMarketId) });

        marketMakingEngine.sendWethToFeeRecipients(invalidMarketId);
    }

    modifier whenTheMarketExist() {
        _;
    }

    function testFuzz_RevertWhen_ThereIsNoAvailableFeesToWithdraw(uint256 marketId)
        external
        givenTheSenderIsRegisteredEngine
        whenTheMarketExist
    {
        changePrank({ msgSender: address(perpsEngine) });

        PerpMarketCreditConfig memory fuzzPerpMarketCreditConfig = getFuzzPerpMarketCreditConfig(marketId);

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.NoWethFeesCollected.selector) });

        marketMakingEngine.sendWethToFeeRecipients(fuzzPerpMarketCreditConfig.marketId);
    }

    modifier whenThereIsAvailableFeesToWithdraw() {
        _;
    }

    function testFuzz_RevertWhen_ThereAreNoFeeRecipientsShares(
        uint256 marketId,
        uint256 amount
    )
        external
        givenTheSenderIsRegisteredEngine
        whenTheMarketExist
        whenThereIsAvailableFeesToWithdraw
    {
        changePrank({ msgSender: address(perpsEngine) });

        PerpMarketCreditConfig memory fuzzPerpMarketCreditConfig = getFuzzPerpMarketCreditConfig(marketId);

        amount = bound({
            x: amount,
            min: USDC_MIN_DEPOSIT_MARGIN,
            max: convertUd60x18ToTokenAmount(address(usdc), USDC_DEPOSIT_CAP_X18)
        });
        deal({ token: address(usdc), to: address(perpsEngine), give: amount });

        marketMakingEngine.receiveMarketFee(fuzzPerpMarketCreditConfig.marketId, address(usdc), amount);

        marketMakingEngine.convertAccumulatedFeesToWeth(
            fuzzPerpMarketCreditConfig.marketId,
            address(usdc),
            uniswapV3Adapter.UNISWAP_V3_SWAP_STRATEGY_ID(),
            bytes("")
        );

        changePrank({ msgSender: address(users.owner.account) });
        marketMakingEngine.configureFeeRecipient(address(perpsEngine), 0);

        changePrank({ msgSender: address(perpsEngine) });

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.NoSharesAvailable.selector) });

        marketMakingEngine.sendWethToFeeRecipients(fuzzPerpMarketCreditConfig.marketId);
    }

    function testFuzz_WhenThereAreFeeRecipientsShares(
        uint256 marketId,
        uint256 amount,
        uint256 quantityOfFeeRecipients,
        uint256 totalFeeRecipientsShares
    )
        external
        givenTheSenderIsRegisteredEngine
        whenTheMarketExist
        whenThereIsAvailableFeesToWithdraw
    {
        changePrank({ msgSender: address(perpsEngine) });

        PerpMarketCreditConfig memory fuzzPerpMarketCreditConfig = getFuzzPerpMarketCreditConfig(marketId);

        amount = bound({
            x: amount,
            min: USDC_MIN_DEPOSIT_MARGIN,
            max: convertUd60x18ToTokenAmount(address(usdc), USDC_DEPOSIT_CAP_X18)
        });
        deal({ token: address(usdc), to: address(perpsEngine), give: amount });

        marketMakingEngine.receiveMarketFee(fuzzPerpMarketCreditConfig.marketId, address(usdc), amount);

        quantityOfFeeRecipients = bound({ x: quantityOfFeeRecipients, min: 1, max: 10 });
        UD60x18 quantityOfFeeRecipientsX18 = convertToUd60x18(quantityOfFeeRecipients);

        totalFeeRecipientsShares = bound({ x: totalFeeRecipientsShares, min: 0.001e18, max: 1e18 });
        UD60x18 totalFeeRecipientsSharesX18 = ud60x18(totalFeeRecipientsShares);

        UD60x18 sharePerFeeRecipientX18 = totalFeeRecipientsSharesX18.div(quantityOfFeeRecipientsX18);

        address[] memory feeRecipients = new address[](quantityOfFeeRecipients);

        changePrank({ msgSender: address(users.owner.account) });

        marketMakingEngine.configureFeeRecipient(address(perpsEngine), 0);

        for (uint256 i = 0; i < quantityOfFeeRecipients; i++) {
            feeRecipients[i] = address(uint160(i + 1));
            marketMakingEngine.configureFeeRecipient(feeRecipients[i], sharePerFeeRecipientX18.intoUint256());
        }

        changePrank({ msgSender: address(perpsEngine) });

        uint256 expectedTokenAmount = uniswapV3Adapter.getExpectedOutput(address(usdc), address(wEth), amount);
        uint256 amountOutMin = uniswapV3Adapter.calculateAmountOutMin(expectedTokenAmount);
        UD60x18 amountOutMinX18 = Math.convertTokenAmountToUd60x18(wEth.decimals(), amountOutMin);

        UD60x18 expectedPendingProtocolWethRewardX18 =
            amountOutMinX18.mul(marketMakingEngine.exposed_getTotalFeeRecipientsShares());

        marketMakingEngine.convertAccumulatedFeesToWeth(
            fuzzPerpMarketCreditConfig.marketId,
            address(usdc),
            uniswapV3Adapter.UNISWAP_V3_SWAP_STRATEGY_ID(),
            bytes("")
        );

        uint256 amountWeth = marketMakingEngine.workaround_getPendingProtocolWethReward(fuzzPerpMarketCreditConfig.marketId);

        UD60x18 expectedFeePerRecipientX18 = ud60x18(amountWeth).mul(sharePerFeeRecipientX18).div(totalFeeRecipientsSharesX18);

        for (uint256 i = 0; i < quantityOfFeeRecipients; i++) {
            assertEq(
                IERC20(address(wEth)).balanceOf(feeRecipients[i]),
                0,
                "the balance of the fee recipient before the send is wrong"
            );
        }

        // it should emit {LogSendWethToFeeRecipients} event
        vm.expectEmit({ emitter: address(marketMakingEngine) });

        emit FeeDistributionBranch.LogSendWethToFeeRecipients(
            uint128(fuzzPerpMarketCreditConfig.marketId), expectedPendingProtocolWethRewardX18.intoUint256()
        );

        marketMakingEngine.sendWethToFeeRecipients(fuzzPerpMarketCreditConfig.marketId);

        // it should transfer the fees to the fee recipients
        for (uint256 i = 0; i < quantityOfFeeRecipients; i++) {
            assertAlmostEq(
                IERC20(address(wEth)).balanceOf(feeRecipients[i]),
                expectedFeePerRecipientX18.intoUint256(),
                1e7,
                "the balance of the fee recipient after the send is wrong"
            );
        }

        // it should decrement the available fees to withdraw
       assertAlmostEq(
            marketMakingEngine.workaround_getPendingProtocolWethReward(fuzzPerpMarketCreditConfig.marketId),
            0,
            quantityOfFeeRecipients + 1,
            "the available fees to withdraw after the send are wrong"
        );
    }
}
