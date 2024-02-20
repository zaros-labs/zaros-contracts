// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { BaseScript } from "../Base.s.sol";
import { AccessKeyManager } from "testnet/access-key-manager/AccessKeyManager.sol";

// Open zeppelin upgradeable dependencies
import { ERC1967Proxy } from "@openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";

// Forge dependencies
import "forge-std/console.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract DeployAccessKeyManager is BaseScript {
    function run() public broadcaster {
        address accessKeyManagerImplementation = address(new AccessKeyManager());

        bytes memory initializeData =
            abi.encodeWithSelector(AccessKeyManager.initialize.selector, deployer, vm.envAddress("SPEARMINT_SIGNER"));

        address accessKeyManagerProxy = address(new ERC1967Proxy(accessKeyManagerImplementation, initializeData));

        console.log("Access Key Manager Implementation: ", accessKeyManagerImplementation);
        console.log("Access Key Manager Proxy: ", accessKeyManagerProxy);
    }
}
