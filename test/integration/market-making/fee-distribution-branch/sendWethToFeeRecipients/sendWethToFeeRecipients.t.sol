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
        changePrank({ msgSender: address(perpsEngine) });

        marketMakingEngine.workaround_setPerpsEngineAddress(address(perpsEngine));

        // Set the market ID and WETH address
        setMarketDebtId(INITIAL_MARKET_DEBT_ID);
        marketMakingEngine.workaround_setWethAddress(address(wEth));
    }

    function testFuzz_RevertGiven_TheCallerIsNotMarketMakingEngine(address user) external {
        changePrank({ msgSender: user });
        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.Unauthorized.selector, user ) });
        marketMakingEngine.sendWethToFeeRecipients(INITIAL_MARKET_DEBT_ID, CONFIGURATION_ID);
    }

    modifier givenTheCallerIsMarketMakingEngine() {
        _;
    }

    function testFuzz_RevertWhen_TheMarketDoesNotExist(uint128 marketId) external givenTheCallerIsMarketMakingEngine {
        vm.assume(marketId != INITIAL_MARKET_DEBT_ID);
        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.UnrecognisedMarket.selector) });
        marketMakingEngine.sendWethToFeeRecipients(marketId, CONFIGURATION_ID);
    }

    modifier whenTheMarketExist() {
        _;
    }

    function test_RevertGiven_ThereIsNoAvailableWeth() external givenTheCallerIsMarketMakingEngine whenTheMarketExist {
        address[] memory addresses = new address[](3);
        addresses[0] = address(users.naruto.account);
        addresses[1] = address(users.sasuke.account);
        addresses[2] = address(users.sakura.account);
        marketMakingEngine.workaround_setFeeRecipients(addresses);

        uint256 configurationPlace = 0;

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.NoWethFeesCollected.selector) });
        marketMakingEngine.sendWethToFeeRecipients(INITIAL_MARKET_DEBT_ID, configurationPlace);
    }

    function testFuuz_GivenThereIsWethAvailable(
        uint256 amountToReceive
    ) 
        external 
        givenTheCallerIsMarketMakingEngine 
        whenTheMarketExist 
    {
        amountToReceive = bound({ x: amountToReceive, min: WETH_MIN_DEPOSIT_MARGIN, max: WETH_DEPOSIT_CAP_X18.intoUint256() });

        marketMakingEngine.workaround_setFeeRecipientsFees(INITIAL_MARKET_DEBT_ID, amountToReceive);

        deal(address(wEth), address(marketMakingEngine), amountToReceive);

        address[] memory addresses = new address[](3);
        addresses[0] = address(users.naruto.account);
        addresses[1] = address(users.sasuke.account);
        addresses[2] = address(users.sakura.account);
        marketMakingEngine.workaround_setFeeRecipients(addresses);

        uint256 userOneShares = 1000;
        uint256 usersShares = 500;
        uint256 totalShares = 2000;
        uint256 configurationPlace = 0;

        // set fee recipients shares 
        marketMakingEngine.workaround_setFeeRecipientShares(address(users.naruto.account), userOneShares);
        marketMakingEngine.workaround_setFeeRecipientShares(address(users.sasuke.account), usersShares);
        marketMakingEngine.workaround_setFeeRecipientShares(address(users.sakura.account), usersShares);

        // Expect event emitted for fee conversion 
        vm.expectEmit();
        emit FeeDistributionBranch.LogSendWethToFeeRecipients(
            address(users.naruto.account),
            (amountToReceive* userOneShares)/totalShares
        );
        vm.expectEmit();
        emit FeeDistributionBranch.LogSendWethToFeeRecipients(
            address(users.sasuke.account), 
            (amountToReceive* usersShares)/totalShares
        );
        vm.expectEmit();
        emit FeeDistributionBranch.LogSendWethToFeeRecipients(
            address(users.sakura.account), 
            (amountToReceive* usersShares)/totalShares
        );

        // it should distribute weth to fee recipients
        marketMakingEngine.sendWethToFeeRecipients(INITIAL_MARKET_DEBT_ID, configurationPlace);
        assertEq(IERC20(address(wEth)).balanceOf(address(users.naruto.account)), (amountToReceive* userOneShares)/totalShares);
        assertEq(IERC20(address(wEth)).balanceOf(address(users.sasuke.account)), (amountToReceive* usersShares)/totalShares);
        assertEq(IERC20(address(wEth)).balanceOf(address(users.sakura.account)), (amountToReceive* usersShares)/totalShares);
    }
}
