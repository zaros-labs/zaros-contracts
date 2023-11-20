// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

// Zaros dependencies
import { Constants } from "@zaros/utils/Constants.sol";
import { BaseScript } from "../Base.s.sol";
import { MockERC20 } from "../../test/mocks/MockERC20.sol";
import { MockUSDToken } from "../../test/mocks/MockUSDToken.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract DeployMockTokens is BaseScript {
    function run() public broadcaster returns (MockERC20, MockERC20, MockUSDToken) {
        MockERC20 sFrxEth = new MockERC20("Staked Frax Ether", "sfrxETH", 18, 1_000_000_000e18);
        MockERC20 usdc = new MockERC20("USD Coin", "USDC", 6, 1_000_000_000e6);
        MockUSDToken usdToken = new MockUSDToken(1_000_000_000e18);

        return (sFrxEth, usdc, usdToken);
    }
}
