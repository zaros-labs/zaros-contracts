// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { BaseScript } from "../Base.s.sol";
import { LimitedMintingERC20 } from "./LimitedMintingERC20.sol";
import { USDToken } from "@zaros/usd/USDToken.sol";
import { Constants } from "@zaros/utils/Constants.sol";
import { FeatureFlag } from "@zaros/utils/storage/FeatureFlag.sol";
import { IUSDToken } from "@zaros/usd/interfaces/IUSDToken.sol";

// Open Zeppelin dependencies
import { Ownable } from "@openzeppelin/access/Ownable.sol";
import { ERC20, ERC20Permit } from "@openzeppelin/token/ERC20/extensions/ERC20Permit.sol";

/// @dev This script is used to deploy a token with limited minting per address. It is intended to be used only at the
/// testnet.
contract DeployLimitedMintingToken is BaseScript {
    function run() public broadcaster returns (address) {
        address tokenERC20 = address(new LimitedMintingERC20(deployer, "USD Coin", "USDC"));

        return tokenERC20;
    }
}
