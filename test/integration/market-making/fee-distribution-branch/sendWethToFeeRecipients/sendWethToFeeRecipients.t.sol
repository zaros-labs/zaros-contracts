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
        createVault();
        changePrank({ msgSender: address(perpsEngine) });

        marketMakingEngine.workaround_setPerpsEngineAddress(address(perpsEngine));

        // Set the market ID and WETH address
        marketMakingEngine.workaround_setMarketId(1, 1);
        marketMakingEngine.workaround_setWethAddress(address(wEth));
    }

    function test_RevertGiven_TheCallerIsNotMarketMakingEngine() external {
        changePrank({ msgSender: users.naruto.account });
        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.Unauthorized.selector, users.naruto.account ) });
        marketMakingEngine.sendWethToFeeRecipients(1, 1);
    }

    modifier givenTheCallerIsMarketMakingEngine() {
        _;
    }

    function test_RevertGiven_TheMarketDoesNotExist() external givenTheCallerIsMarketMakingEngine {
        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.UnrecognisedMarket.selector) });
        marketMakingEngine.sendWethToFeeRecipients(2, 1);
    }

    modifier givenTheMarketExist() {
        _;
    }

    function test_RevertGiven_ThereIsNoAvailableWeth()
        external
        givenTheCallerIsMarketMakingEngine
        givenTheMarketExist
    {
        address[] memory addresses = new address[](3);
        addresses[0] = address(users.naruto.account);
        addresses[1] = address(users.sasuke.account);
        addresses[2] = address(users.sakura.account);
        marketMakingEngine.workaround_setFeeRecipients(addresses);
        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.NoWethFeesCollected.selector) });
        marketMakingEngine.sendWethToFeeRecipients(1, 0);
    }

    function test_GivenThereIsWethAvailable()
        external
        givenTheCallerIsMarketMakingEngine
        givenTheMarketExist
    {
        marketMakingEngine.workaround_setFeeRecipientsFees(1, 10e18);

        deal(address(wEth), address(marketMakingEngine), 10e18);

        address[] memory addresses = new address[](3);
        addresses[0] = address(users.naruto.account);
        addresses[1] = address(users.sasuke.account);
        addresses[2] = address(users.sakura.account);
        marketMakingEngine.workaround_setFeeRecipients(addresses);

        marketMakingEngine.workaround_setFeeRecipientShares(address(users.naruto.account), 1000);
        marketMakingEngine.workaround_setFeeRecipientShares(address(users.sasuke.account), 500);
        marketMakingEngine.workaround_setFeeRecipientShares(address(users.sakura.account), 500);

        // Expect event emitted for fee conversion 
        vm.expectEmit();
        emit FeeDistributionBranch.LogSendWethToFeeRecipients(address(users.naruto.account), 5e18);
        vm.expectEmit();
        emit FeeDistributionBranch.LogSendWethToFeeRecipients(address(users.sasuke.account), 25e17);
        vm.expectEmit();
        emit FeeDistributionBranch.LogSendWethToFeeRecipients(address(users.sakura.account), 25e17);

        // it should distribute weth to fee recipients
        marketMakingEngine.sendWethToFeeRecipients(1, 0);

        assertEq(IERC20(address(wEth)).balanceOf(address(users.sasuke.account)), 25e17);
        assertEq(IERC20(address(wEth)).balanceOf(address(users.naruto.account)), 5e18);
        assertEq(IERC20(address(wEth)).balanceOf(address(users.sakura.account)), 25e17);
    }
}
