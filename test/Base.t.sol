// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { AccountNFT } from "@zaros/account-nft/AccountNFT.sol";
import { Zaros } from "@zaros/core/Zaros.sol";
import { PerpsManager } from "@zaros/markets/perpetual-futures/manager/PerpsManager.sol";
import { RewardDistributor } from "@zaros/reward-distributor/RewardDistributor.sol";
import { MockZarosUSD } from "./mocks/MockZarosUSD.sol";
import { Constants } from "./utils/Constants.sol";
import { Events } from "./utils/Events.sol";
import { Users } from "./utils/Types.sol";

// Forge dependencies
import { Test } from "forge-std/Test.sol";

// Open Zeppelin dependencies
import { IERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";

contract Base_Test is Test, Constants, Events {
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
        users = Users({
            owner: createUser({ name: "Owner" }),
            naruto: createUser({ name: "Naruto Uzumaki" }),
            sasuke: createUser({ name: "Sasuke Uchiha" }),
            sakura: createUser({ name: "Sakura Haruno" }),
            madara: createUser({ name: "Madara Uchiha" })
        });
        vm.startPrank({ msgSender: users.owner });

        accountToken = new AccountNFT("Zaros Trading Accounts", "ZRS-TRADE-ACC");
        zrsUsd = new MockZarosUSD({ ownerBalance: 100_000_000e18 });
        zaros = Zaros(mockZarosAddress);
        rewardDistributor = RewardDistributor(mockRewardDistributorAddress);
        perpsManager = new PerpsManager(address(accountToken), address(mockRewardDistributorAddress), address(zaros));

        accountToken.transferOwnership(address(perpsManager));
        distributeTokens();

        vm.label({ account: address(accountToken), newLabel: "Perps Account Token" });
        vm.label({ account: address(zrsUsd), newLabel: "Zaros USD" });
        vm.label({ account: address(zaros), newLabel: "Zaros" });
        vm.label({ account: address(rewardDistributor), newLabel: "Reward Distributor" });
        vm.label({ account: address(perpsManager), newLabel: "Perps Manager" });
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      HELPERS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Generates a user, labels its address, and funds it with test assets.
    function createUser(string memory name) internal returns (address payable) {
        address payable user = payable(makeAddr(name));
        vm.deal({ account: user, newBalance: 100 ether });

        return user;
    }

    /// @dev Approves all Zaros contracts to spend the test assets.
    function approveContracts() internal {
        changePrank({ msgSender: users.naruto });
        zrsUsd.approve({ spender: address(perpsManager), amount: MAX_UINT256 });

        changePrank({ msgSender: users.sasuke });
        zrsUsd.approve({ spender: address(perpsManager), amount: MAX_UINT256 });

        changePrank({ msgSender: users.sakura });
        zrsUsd.approve({ spender: address(perpsManager), amount: MAX_UINT256 });

        changePrank({ msgSender: users.madara });
        zrsUsd.approve({ spender: address(perpsManager), amount: MAX_UINT256 });

        // Finally, change the active prank back to the Admin.
        changePrank({ msgSender: users.owner });
    }

    function distributeTokens() internal {
        deal({ token: address(zrsUsd), to: users.naruto, give: 1_000_000e18 });

        deal({ token: address(zrsUsd), to: users.sasuke, give: 1_000_000e18 });

        deal({ token: address(zrsUsd), to: users.sakura, give: 1_000_000e18 });

        deal({ token: address(zrsUsd), to: users.madara, give: 1_000_000e18 });
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    CALL EXPECTS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Expects a call to {IERC20.transfer}.
    function expectCallToTransfer(IERC20 asset, address to, uint256 amount) internal {
        vm.expectCall({ callee: address(asset), data: abi.encodeCall(IERC20.transfer, (to, amount)) });
    }

    /// @dev Expects a call to {IERC20.transferFrom}.
    function expectCallToTransferFrom(IERC20 asset, address from, address to, uint256 amount) internal {
        vm.expectCall({ callee: address(asset), data: abi.encodeCall(IERC20.transferFrom, (from, to, amount)) });
    }
}
