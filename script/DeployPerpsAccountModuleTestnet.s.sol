// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { BaseScript } from "./Base.s.sol";
import { PerpsAccountModuleTestnet } from "../testnet/modules/PerpsAccountModuleTestnet.sol";

// Open zeppelin upgradeable dependencies
import { ERC1967Proxy } from "@openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";

// Forge dependencies
import "forge-std/console.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract DeployPerpsAccountModuleTestnet is BaseScript {
    function run() public broadcaster {
        address accessKeyManager = vm.envAddress("CONTRACT_ACCESS_KEY_MANAGER");
        address perpsAccountModuleTestnet = address(new PerpsAccountModuleTestnet(accessKeyManager));

        console.log("Perps Account Module Testnet: ", perpsAccountModuleTestnet);
    }
}
