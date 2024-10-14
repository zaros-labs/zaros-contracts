// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { FeeDistributionBranch } from "@zaros/market-making/branches/FeeDistributionBranch.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

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

    function testFuzz_RevertWhen_TheAssetIsNotEnabled(
        uint256 marketDebtId
    )
        external
        givenTheSenderIsRegisteredEngine
        whenTheMarketExist
        whenTheAmountIsNotZero
    {
        changePrank({ msgSender: address(perpsEngine) });

        MarketDebtConfig memory fuzzMarketDebtConfig = getFuzzMarketDebtConfig(marketDebtId);

        address assetNotEnabled = address(0x123);

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.CollateralDisabled.selector, address(0)) });

        marketMakingEngine.receiveMarketFee(fuzzMarketDebtConfig.marketDebtId, assetNotEnabled, 1);
    }

    function test_WhenTheAssetIsEnabled(
        uint256 marketDebtId,
        uint256 amount
    )
        external
        givenTheSenderIsRegisteredEngine
        whenTheMarketExist
        whenTheAmountIsNotZero
    {
        changePrank({ msgSender: address(perpsEngine) });

        MarketDebtConfig memory fuzzMarketDebtConfig = getFuzzMarketDebtConfig(marketDebtId);

        amount = bound({
            x: amount,
            min: USDC_MIN_DEPOSIT_MARGIN,
            max: convertUd60x18ToTokenAmount(address(usdc), USDC_DEPOSIT_CAP_X18)
        });
        deal({ token: address(usdc), to: address(perpsEngine), give: amount });

        // it should emit {LogReceiveMarketFee} event
        vm.expectEmit({ emitter: address(marketMakingEngine) });
        emit FeeDistributionBranch.LogReceiveMarketFee(address(usdc), fuzzMarketDebtConfig.marketDebtId, amount);

        marketMakingEngine.receiveMarketFee(fuzzMarketDebtConfig.marketDebtId, address(usdc), amount);

        // it should increment received market fee
        uint256 receivedMarketFeeX18 =
            marketMakingEngine.workaround_getReceivedMarketFees(fuzzMarketDebtConfig.marketDebtId, address(usdc));
        UD60x18 amountX18 = convertTokenAmountToUd60x18(address(usdc), amount);
        assertEq(amountX18.intoUint256(), receivedMarketFeeX18);

        // it should transfer the fee to the contract
        assertEq(usdc.balanceOf(address(marketMakingEngine)), amount);
        assertEq(usdc.balanceOf(address(perpsEngine)), 0);
    }
}
