// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { FeeDistributionBranch } from "@zaros/market-making/branches/FeeDistributionBranch.sol";

// Openzeppelin dependencies
import { IERC20 } from "@openzeppelin/token/ERC20/IERC20.sol";

contract ReceiveMarketFee_Integration_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: address(users.owner.account) });
        configureMarketsDebt();
    }

    function testFuzz_RevertGiven_TheSenderIsNotRegisteredEngine(uint256 marketDebtId, uint256 amount) external {
        changePrank({ msgSender: users.naruto.account });

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.Unauthorized.selector, users.naruto.account) });
        marketMakingEngine.receiveMarketFee(uint128(marketDebtId), address(usdc), amount);
    }

    modifier givenTheSenderIsRegisteredEngine() {
        _;
    }

    function testFuzz_RevertWhen_TheMarketDoesNotExist(uint256 amount) external givenTheSenderIsRegisteredEngine {
        changePrank({ msgSender: address(perpsEngine) });

        uint128 invalidMarketDebtId = FINAL_MARKET_DEBT_ID + 1;

        amount = bound({
            x: amount,
            min: USDC_MIN_DEPOSIT_MARGIN,
            max: convertUd60x18ToTokenAmount(address(usdc), USDC_DEPOSIT_CAP_X18)
        });
        deal({ token: address(usdc), to: address(perpsEngine), give: amount });

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.UnrecognisedMarket.selector, invalidMarketDebtId) });

        marketMakingEngine.receiveMarketFee(invalidMarketDebtId, address(usdc), amount);
    }

    modifier whenTheMarketExist() {
        _;
    }

    function testFuzz_RevertWhen_TheAmountIsZero(
        uint256 marketDebtId
    )
        external
        givenTheSenderIsRegisteredEngine
        whenTheMarketExist
    {
        changePrank({ msgSender: address(perpsEngine) });

        MarketDebtConfig memory fuzzMarketDebtConfig = getFuzzMarketDebtConfig(marketDebtId);

        uint256 amount = 0;

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "amount") });

        marketMakingEngine.receiveMarketFee(fuzzMarketDebtConfig.marketDebtId, address(usdc), amount);
    }

    modifier whenTheAmountIsNotZero() {
        _;
    }

    function test_RevertWhen_TheAssetIsNotEnabled(
        uint256 amountToReceive
    )
        external
        givenTheSenderIsRegisteredEngine
        whenTheMarketExist
        whenTheAmountIsNotZero
    {
        // amountToReceive =
        //     bound({ x: amountToReceive, min: WETH_MIN_DEPOSIT_MARGIN, max: WETH_DEPOSIT_CAP_X18.intoUint256() });

        // // it should revert
        // vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.CollateralDisabled.selector, address(0)) });
        // marketMakingEngine.receiveMarketFee(INITIAL_MARKET_DEBT_ID, address(wBtc), amountToReceive);
    }

    function test_WhenTheAssetIsEnabled(
        uint256 amountToReceive
    )
        external
        givenTheSenderIsRegisteredEngine
        whenTheMarketExist
        whenTheAmountIsNotZero
    {
        // amountToReceive =
        //     bound({ x: amountToReceive, min: WETH_MIN_DEPOSIT_MARGIN, max: WETH_DEPOSIT_CAP_X18.intoUint256() });

        // deal(address(wEth), address(perpsEngine), amountToReceive);
        // IERC20(address(wEth)).approve(address(marketMakingEngine), amountToReceive);

        // it should emit event { LogReceiveMarketFee }
        // vm.expectEmit();
        // emit FeeDistributionBranch.LogReceiveMarketFee(address(wEth), amountToReceive);

        // // it should receive tokens
        // marketMakingEngine.receiveMarketFee(INITIAL_MARKET_DEBT_ID, address(wEth), amountToReceive);
        // assertEq(IERC20(address(wEth)).balanceOf(address(marketMakingEngine)), amountToReceive);
    }
}
