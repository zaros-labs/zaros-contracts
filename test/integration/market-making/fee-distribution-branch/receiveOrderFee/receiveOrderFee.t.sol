// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { FeeDistributionBranch } from "@zaros/market-making/branches/FeeDistributionBranch.sol";

// Openzeppelin dependencies
import { IERC20 } from "@openzeppelin/token/ERC20/IERC20.sol";

contract ReceiveOrderFee_Integration_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: address(perpsEngine) });

        setMarketDebtId(INITIAL_MARKET_DEBT_ID);

        marketMakingEngine.workaround_setPerpsEngineAddress(address(perpsEngine));

        marketMakingEngine.workaround_Collateral_setParams(
            address(wEth),
            WETH_CORE_VAULT_CREDIT_RATIO,
            WETH_CORE_VAULT_IS_ENABLED,
            WETH_DECIMALS,
            address(0)
        );
    }

    function testFuzz_RevertGiven_TheCallerIsNotMarketMakingEngine(address user, uint256 assetsToDeposit) external {
        vm.assume(user != address(perpsEngine));

        changePrank({ msgSender: user });

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.Unauthorized.selector, user) });
        marketMakingEngine.receiveMarketFee(INITIAL_MARKET_DEBT_ID, address(wBtc), assetsToDeposit);
    }

    modifier givenTheCallerIsMarketMakingEngine() {
        _;
    }

    function testFuzz_RevertWhen_MarketDoesNotExist(
        uint128 marketId,
        uint256 assetsToDeposit
    )
        external
        givenTheCallerIsMarketMakingEngine
    {
        vm.assume(marketId != INITIAL_MARKET_DEBT_ID);

        deal(address(wEth), address(perpsEngine), assetsToDeposit);

        IERC20(address(wEth)).approve(address(marketMakingEngine), assetsToDeposit);

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.UnrecognisedMarket.selector) });
        marketMakingEngine.receiveMarketFee(marketId, address(wEth), assetsToDeposit);
    }

    modifier whenMarketExist() {
        _;
    }

    function test_RevertGiven_AssetIsNotEnabled(
        uint256 amountToReceive
    )
        external
        givenTheCallerIsMarketMakingEngine
        whenMarketExist
    {
        amountToReceive =
            bound({ x: amountToReceive, min: WETH_MIN_DEPOSIT_MARGIN, max: WETH_DEPOSIT_CAP_X18.intoUint256() });

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.CollateralDisabled.selector, address(0)) });
        marketMakingEngine.receiveMarketFee(INITIAL_MARKET_DEBT_ID, address(wBtc), amountToReceive);
    }

    modifier givenAssetIsEnabled() {
        _;
    }

    function test_RevertWhen_TheAmountIsZero()
        external
        givenTheCallerIsMarketMakingEngine
        whenMarketExist
        givenAssetIsEnabled
    {
        uint256 zeroAmount = 0;

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "amount") });
        marketMakingEngine.receiveMarketFee(INITIAL_MARKET_DEBT_ID, address(wEth), zeroAmount);
    }

    function testFuzz_WhenTheAmountIsNotZero(
        uint256 amountToReceive
    )
        external
        givenTheCallerIsMarketMakingEngine
        whenMarketExist
        givenAssetIsEnabled
    {
        amountToReceive =
            bound({ x: amountToReceive, min: WETH_MIN_DEPOSIT_MARGIN, max: WETH_DEPOSIT_CAP_X18.intoUint256() });

        deal(address(wEth), address(perpsEngine), amountToReceive);
        IERC20(address(wEth)).approve(address(marketMakingEngine), amountToReceive);

        // it should emit event { LogReceiveMarketFee }
        // vm.expectEmit();
        // emit FeeDistributionBranch.LogReceiveMarketFee(address(wEth), amountToReceive);

        // // it should receive tokens
        // marketMakingEngine.receiveMarketFee(INITIAL_MARKET_DEBT_ID, address(wEth), amountToReceive);
        // assertEq(IERC20(address(wEth)).balanceOf(address(marketMakingEngine)), amountToReceive);
    }
}
