// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { AccountNFT } from "@zaros/account-nft/AccountNFT.sol";
import { Zaros } from "@zaros/core/Zaros.sol";
import { PerpsManager } from "@zaros/markets/perpetual-futures/manager/PerpsManager.sol";
import { RewardDistributor } from "@zaros/reward-distributor/RewardDistributor.sol";
import { MockZarosUSD } from "test/mocks/MockZarosUSD.sol";
import { Base_Test } from "test/Base.t.sol";

// Forge dependencies
import { Test } from "forge-std/Test.sol";

contract PerpsAccountModule_Unit_Test is Base_Test {
    function test_createAccount() public {
        (uint256 accountId) = perpsManager.createAccount();
    }

    function test_createAccountAndMulticall() public { }
}
