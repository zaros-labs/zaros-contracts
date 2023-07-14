// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { AccountNFT } from "@zaros/account-nft/AccountNFT.sol";
import { Zaros } from "@zaros/core/Zaros.sol";
import { MockERC20 } from "@zaros/mocks/MockERC20.sol";

// Forge dependencies
import { Test } from "forge-std/Test.sol";

contract ZarosIntegrationTest is Test {
    address[] internal users = [vm.addr(1)];
    AccountNFT internal accountNft;
    Zaros internal zaros;
    MockERC20 internal sFrxEth;
    MockERC20 internal usdc;

    function setUp() public {
        startHoax(users[0]);
        accountNft = new AccountNFT();
        zaros = new Zaros(address(accountNft));
        accountNft.transferOwnership(address(zaros));
        sFrxEth = new MockERC20("Staked Frax Ether", "sfrxETH", 18);
        usdc = new MockERC20("USD Coin", "USDC", 6);

        sFrxEth.approve(address(zaros), type(uint256).max);
        usdc.approve(address(zaros), type(uint256).max);
    }

    function test_Integration_LpsCanDepositAndWithdraw() public {
        // uint256 requestedAccountId = accountNft.zaros.createAccount();
        // uint256 userAccountId = accountNft.tokenOfOwnerByIndex(users[0], 0);
        // zaros.deposit(userAccountId, address(sFrxEth), 1e18);
    }
}
