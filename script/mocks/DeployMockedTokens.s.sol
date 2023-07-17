// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

// Zaros dependencies
import { BaseScript } from "../Base.s.sol";
import { MockERC20 } from "../../test/mocks/MockERC20.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract Deploy is BaseScript {
    function run() public broadcaster returns (address, address) {
        MockERC20 sFrxEth = new MockERC20("Staked Frax Ether", "sfrxETH", 18);
        MockERC20 usdc = new MockERC20("USD Coin", "USDC", 6);

        sFrxEth.mint(deployer, 100_000_000e18);
        usdc.mint(deployer, 100_000_000e6);

        return (address(sFrxEth), address(usdc));
    }
}
