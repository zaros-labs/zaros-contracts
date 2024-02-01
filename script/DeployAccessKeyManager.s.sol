// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { BaseScript } from "./Base.s.sol";
import { AccessKeyManager } from "@zaros/access-key-manager/AccessKeyManager.sol";

// Forge dependencies
import "forge-std/console.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract DeployAccessKeyManager is BaseScript {
    function run() public broadcaster {
        address accessKeyManager = address(new AccessKeyManager(vm.envAddress("SPEARMINT_ADDRESS")));

        console.log("AccessKeyManager: ");
        console.log(accessKeyManager);
    }
}
