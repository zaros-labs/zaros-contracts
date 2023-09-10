// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { AccountNFT } from "@zaros/account-nft/AccountNFT.sol";
import { Zaros } from "@zaros/core/Zaros.sol";
import { PerpsManager } from "@zaros/markets/perpetual-futures/manager/PerpsManager.sol";
import { RewardDistributor } from "@zaros/reward-distributor/RewardDistributor.sol";
import { MockZarosUSD } from "./mocks/MockZarosUSD.sol";

// Forge dependencies
import { Test } from "forge-std/Test.sol";

contract Base_Test is Test {
    address internal deployer = vm.addr(1);
    address internal mockZarosAddress = vm.addr(2);
    address internal mockRewardDistributorAddress = vm.addr(3);

    AccountNFT internal accountToken;
    MockZarosUSD internal zrsUsd;
    PerpsManager internal perpsManager;
    RewardDistributor internal rewardDistributor;
    Zaros internal zaros;

    function setUp() public {
        accountToken = new AccountNFT("Zaros Trading Accounts", "ZRS-TRADE-ACC");
        zrsUsd = new MockZarosUSD(100_000_000e18);
        zaros = Zaros(mockZarosAddress);
        rewardDistributor = RewardDistributor(mockRewardDistributorAddress);
        perpsManager = new PerpsManager(address(accountToken), address(mockRewardDistributorAddress), address(zaros));
    }
}
