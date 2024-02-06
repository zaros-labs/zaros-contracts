// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { BaseScript } from "../Base.s.sol";
import { ERC20Implementation } from "./ERC20Implementation.sol";
import { USDToken } from "@zaros/usd/USDToken.sol";
import { Constants } from "@zaros/utils/Constants.sol";
import { FeatureFlag } from "@zaros/utils/storage/FeatureFlag.sol";
import { IUSDToken } from "@zaros/usd/interfaces/IUSDToken.sol";

// Open Zeppelin dependencies
import { Ownable } from "@openzeppelin/access/Ownable.sol";
import { ERC20, ERC20Permit } from "@openzeppelin/token/ERC20/extensions/ERC20Permit.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract DeployLimitedMintingToken is BaseScript {
    function run() public broadcaster returns (address) {
        address tokenERC20 = address(new ERC20Implementation(deployer, "ERC20 Token", "ERC20"));

        return tokenERC20;
    }
}
