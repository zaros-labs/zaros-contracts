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

    function test_RevertWhen_TheMarketDoesNotExist(
        uint256 marketDebtId,
        uint256 amount
    )
        external
        givenTheSenderIsRegisteredEngine
    {
        changePrank({ msgSender: address(perpsEngine) });

        MarketDebtConfig memory marketDebtConfig = getFuzzMarketDebtConfig(marketDebtId);

        // // it should revert
        // vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.UnrecognisedMarket.selector, uint128(marketId))
        // });
        // marketMakingEngine.receiveMarketFee(uint128(marketId), address(usdc), amount);
    }

    modifier whenTheMarketExist() {
        _;
    }

    function test_RevertWhen_TheAmountIsZero() external givenTheSenderIsRegisteredEngine whenTheMarketExist {
        // uint256 zeroAmount = 0;

        // // it should revert
        // vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "amount") });
        // marketMakingEngine.receiveMarketFee(INITIAL_MARKET_DEBT_ID, address(wEth), zeroAmount);
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
