// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { BaseScript } from "./Base.s.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract Deploy is BaseScript {
    function run() public broadcaster returns (address) {
        // foo = new Foo();
        return (address(0));
    }
}
