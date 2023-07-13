// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

// Zaros dependencies
import { BaseScript } from "./Base.s.sol";
import { Zaros } from "@zaros/core/Zaros.sol";

// Open Zeppelin dependencies
import { ERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";
import { ERC721 } from "@openzeppelin/token/ERC721/ERC721.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract Deploy is BaseScript {
    function run() public broadcaster returns (address) { }
}
