// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";
import { Errors } from "@zaros/utils/Errors.sol";

import "forge-std/console.sol";
// Uniswap dependencies
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

contract Fee_Uniswap_SetSwapRouterAddress_Unit_Test is Base_Test {
    function test_RevertWhen_SetSwapRouterAddressIsPassedZeroAddress() external {
        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.SwapRouterAddressUndefined.selector) });
        marketMakingEngine.exposed_setUniswapRouterAddress(address(0));
    }

    function test_WhenSetSwapRouterAddressIsPassedValidAddress() external {
        // it should set address        
        marketMakingEngine.exposed_setUniswapRouterAddress(address(5));
    }
}
