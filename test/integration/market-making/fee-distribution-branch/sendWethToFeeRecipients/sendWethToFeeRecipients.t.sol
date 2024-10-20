// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { FeeDistributionBranch } from "@zaros/market-making/branches/FeeDistributionBranch.sol";

// Openzeppelin dependencies
import { IERC20 } from "@openzeppelin/token/ERC20/extensions/ERC4626.sol";
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";

contract SendWethToFeeRecipients_Integration_Test is Base_Test {
    using EnumerableSet for EnumerableSet.UintSet;

    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: address(users.owner.account) });
        configureMarketsDebt();
    }

    function testFuzz_RevertGiven_TheSenderIsNotRegisteredEngine(uint256 marketId, uint256 configuration) external {
        changePrank({ msgSender: users.naruto.account });

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.Unauthorized.selector, users.naruto.account) });
        marketMakingEngine.sendWethToFeeRecipients(uint128(marketId), configuration);
    }

    modifier givenTheSenderIsRegisteredEngine() {
        _;
    }

    function testFuzz_RevertWhen_TheMarketDoesNotExist(uint256 configuration) external givenTheSenderIsRegisteredEngine {
        changePrank({ msgSender: address(perpsEngine) });

        uint128 invalidMarketDebtId = FINAL_MARKET_DEBT_ID + 1;

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.MarketDoesNotExist.selector, invalidMarketDebtId) });

        marketMakingEngine.sendWethToFeeRecipients(invalidMarketDebtId, configuration);
    }

    modifier whenTheMarketExist() {
        _;
    }

    function testFuzz_RevertWhen_ThereIsNoAvailableFeesToWithdraw(uint256 marketId, uint256 configuration)
        external
        givenTheSenderIsRegisteredEngine
        whenTheMarketExist
    {
        changePrank({ msgSender: address(perpsEngine) });

        PerpMarketCreditConfig memory fuzzPerpMarketCreditConfig = getFuzzPerpMarketCreditConfig(marketId);

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.NoWethFeesCollected.selector) });

        marketMakingEngine.sendWethToFeeRecipients(fuzzPerpMarketCreditConfig.marketId, configuration);
    }

    modifier whenThereIsAvailableFeesToWithdraw() {
        _;
    }

    function testFuzz_RevertWhen_ThereAreNoFeeRecipients(uint256 marketId, uint256 configuration, uint256 amount)
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

        marketMakingEngine.convertAccumulatedFeesToWeth(fuzzPerpMarketCreditConfig.marketId, address(usdc), uniswapV3Adapter.UNISWAP_V3_SWAP_STRATEGY_ID());

        // TODO: add custom error
        // it should revert
        vm.expectRevert({ });

        marketMakingEngine.sendWethToFeeRecipients(fuzzPerpMarketCreditConfig.marketId, configuration);
    }

    function test_WhenThereAreFeeRecipients()
        external
        givenTheSenderIsRegisteredEngine
        whenTheMarketExist
        whenThereIsAvailableFeesToWithdraw
    {
        // it should transfer the fees to the fee recipients
        // it should emit {LogSendWethToFeeRecipients} event
        // it should decrement the available fees to withdraw
    }

}
