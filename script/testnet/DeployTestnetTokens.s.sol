// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { BaseScript } from "../Base.s.sol";
import { LimitedMintingERC20 } from "testnet/LimitedMintingERC20.sol";
import { Constants } from "@zaros/utils/Constants.sol";
import { FeatureFlag } from "@zaros/utils/storage/FeatureFlag.sol";

// Open Zeppelin dependencies
import { ERC1967Proxy } from "@openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";

// Forge dependencies
import "forge-std/console.sol";

/// @dev This script is used to deploy a token with limited minting per address. It is intended to be used only at the
/// testnet.
contract DeployTestnetTokens is BaseScript {
    function run() public broadcaster {
        address limitedMintingErc20Implementation = address(new LimitedMintingERC20());

        address accessKeyManager = vm.envOr("CONTRACT_ACCESS_KEY_MANAGER", address(0));

        bytes memory usdcInitializeData = abi.encodeWithSelector(
            LimitedMintingERC20.initialize.selector, deployer, "USD Coin", "USDC", address(accessKeyManager)
        );
        bytes memory usdzInitializeData = abi.encodeWithSelector(
            LimitedMintingERC20.initialize.selector, deployer, "Zaros USD", "USDz", address(accessKeyManager)
        );

        address usdc = address(new ERC1967Proxy(limitedMintingErc20Implementation, usdcInitializeData));
        address usdz = address(new ERC1967Proxy(limitedMintingErc20Implementation, usdzInitializeData));

        console.log("Limited Minting ERC20 Implementation: ", limitedMintingErc20Implementation);
        console.log("USDC Proxy: ", usdc);
        console.log("USDz Proxy: ", usdz);
    }
}
