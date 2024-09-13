// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { Collateral } from "@zaros/market-making/leaves/Collateral.sol";
import { FeeDistributionBranch } from "@zaros/market-making/branches/FeeDistributionBranch.sol";

import "forge-std/console.sol";

// Openzeppelin dependencies
import { IERC20 } from "@openzeppelin/token/ERC20/extensions/ERC4626.sol";
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";

contract MarketMaking_FeeDistribution_sendWethToFeeRecipients is Base_Test {
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

    function test_RevertGiven_TheCallerIsNotPerpsEngine() external {
        changePrank({ msgSender: users.naruto.account });
        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.Unauthorized.selector, users.naruto.account ) });
        marketMakingEngine.sendWethToFeeRecipients(1, 1);
    }

    modifier givenTheCallerIsPerpsEngine() {
        _;
    }

    function test_RevertGiven_TheMarketDoesNotExist() external givenTheCallerIsPerpsEngine {
        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.UnrecognisedMarket.selector) });
        marketMakingEngine.sendWethToFeeRecipients(2, 1);
    }

    modifier givenTheMarketExist() {
        _;
    }

    function test_RevertGiven_ThereIsNoAvailableWeth()
        external
        givenTheCallerIsPerpsEngine
        givenTheMarketExist
    {
        address[] memory addresses = new address[](3);
        addresses[0] = address(3);
        addresses[1] = address(1);
        addresses[2] = address(2);
        marketMakingEngine.workaround_setFeeRecipients(addresses);
        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.NoWethFeesCollected.selector) });
        marketMakingEngine.sendWethToFeeRecipients(1, 0);
    }

    function test_GivenThereIsWethAvailable()
        external
        givenTheCallerIsPerpsEngine
        givenTheMarketExist
    {
        marketMakingEngine.workaround_setFeeRecipientsFees(1, 10e18);

        deal(address(wEth), 0x763d32e23401eAD917023881999Dbd38Aa76C25F, 10e18);

        address[] memory addresses = new address[](3);
        addresses[0] = address(3);
        addresses[1] = address(1);
        addresses[2] = address(2);
        marketMakingEngine.workaround_setFeeRecipients(addresses);

        marketMakingEngine.workaround_setFeeRecipientShares(address(1), 1000);
        marketMakingEngine.workaround_setFeeRecipientShares(address(2), 500);
        marketMakingEngine.workaround_setFeeRecipientShares(address(3), 500);

        // Expect event emitted for fee conversion 
        vm.expectEmit();
        emit FeeDistributionBranch.TransferCompleted(address(3), 25e17);
        vm.expectEmit();
        emit FeeDistributionBranch.TransferCompleted(address(1), 5e18);
        vm.expectEmit();
        emit FeeDistributionBranch.TransferCompleted(address(2), 25e17);

        // it should distribute weth to fee recipients
        marketMakingEngine.sendWethToFeeRecipients(1, 0);

        assertEq(IERC20(address(wEth)).balanceOf(address(2)), 25e17);
        assertEq(IERC20(address(wEth)).balanceOf(address(1)), 5e18);
        assertEq(IERC20(address(wEth)).balanceOf(address(3)), 25e17);
    }
}
