// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { AccountNFT } from "@zaros/account-nft/AccountNFT.sol";
import { Zaros } from "@zaros/core/Zaros.sol";
import { PerpsManager } from "@zaros/markets/perpetual-futures/manager/PerpsManager.sol";
import { RewardDistributor } from "@zaros/reward-distributor/RewardDistributor.sol";
import { MockZarosUSD } from "./mocks/MockZarosUSD.sol";
import { Users } from "./utils/Types.sol";

// Forge dependencies
import { Test } from "forge-std/Test.sol";

contract Base_Test is Test {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/
    Users internal users;

    /// @dev TODO: deploy real contracts instead of mocking them
    address internal mockZarosAddress = vm.addr({ privateKey: 0x02 });
    address internal mockRewardDistributorAddress = vm.addr({ privateKey: 0x03 });

    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    AccountNFT internal accountToken;
    MockZarosUSD internal zrsUsd;
    PerpsManager internal perpsManager;
    RewardDistributor internal rewardDistributor;
    Zaros internal zaros;

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/
    function setUp() public virtual {
        accountToken = new AccountNFT("Zaros Trading Accounts", "ZRS-TRADE-ACC");
        zrsUsd = new MockZarosUSD({ ownerBalance: 100_000_000e18 });
        zaros = Zaros(mockZarosAddress);
        rewardDistributor = RewardDistributor(mockRewardDistributorAddress);
        perpsManager = new PerpsManager(address(accountToken), address(mockRewardDistributorAddress), address(zaros));

        vm.label({ account: address(accountToken), newLabel: "Perps Account Token" });
        vm.label({ account: address(zrsUsd), newLabel: "Zaros USD" });
        vm.label({ account: address(zaros), newLabel: "Zaros" });
        vm.label({ account: address(rewardDistributor), newLabel: "Reward Distributor" });
        vm.label({ account: address(perpsManager), newLabel: "Perps Manager" });

        users = Users({
            owner: createUser({ name: "Owner" }),
            naruto: createUser({ name: "Naruto Uzumaki" }),
            sasuke: createUser({ name: "Sasuke Uchiha" }),
            sakura: createUser({ name: "Sakura Haruno" }),
            madara: createUser({ name: "Madara Uchiha" })
        });
    }

    /// @dev Generates a user, labels its address, and funds it with test assets.
    function createUser(string memory name) internal returns (address payable) {
        address payable user = payable(makeAddr(name));
        vm.deal({ account: user, newBalance: 100 ether });
        deal({ token: address(zrsUsd), to: user, give: 1_000_000e18 });

        return user;
    }
}
