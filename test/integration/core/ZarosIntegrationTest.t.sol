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
        uint256 amount = 100e18;
        _createAccountDepositAndDelegate(address(sFrxEth), amount);
        // Asserts that the Zaros account has the expected balance of sFrxEth
        assertEq(sFrxEth.balanceOf(address(zaros)), amount);
        // get account id of the user's first created account
        // TODO: improve handling account id query
        uint128 accountId = uint128(accountNft.tokenOfOwnerByIndex(users[0], 0));
        _undelegateAndWithdraw(accountId, address(sFrxEth), amount);
        assertEq(sFrxEth.balanceOf(address(zaros)), 0);
    }

    function _createAccountDepositAndDelegate(address collateralType, uint256 amount) internal {
        bytes memory depositData = abi.encodeWithSelector(zaros.deposit.selector, collateralType, amount);
        bytes memory delegateCollateralData =
            abi.encodeWithSelector(zaros.delegateCollateral.selector, collateralType, amount);
        bytes[] memory data = new bytes[](2);
        data[0] = depositData;
        data[1] = delegateCollateralData;

        // Creates a new Zaros account and calls `deposit` and `delegateCollateral` in the same transaction
        zaros.createAccountAndMulticall(data);
    }

    function _undelegateAndWithdraw(uint128 accountId, address collateralType, uint256 amount) internal {
        (uint256 positionCollateralAmount, uint256 positionCollateralValue) =
            zaros.getPositionCollateral(accountId, collateralType);
        uint256 newAmount = positionCollateralAmount - amount;
        bytes memory delegateCollateralData =
            abi.encodeWithSelector(zaros.delegateCollateral.selector, accountId, collateralType, newAmount);
        bytes memory withdrawData = abi.encodeWithSelector(zaros.withdraw.selector, accountId, collateralType, amount);
        bytes[] memory data = new bytes[](2);
        data[0] = delegateCollateralData;
        data[1] = withdrawData;

        // Undelegates and withdraws the given amount of sFrxEth
        zaros.multicall(data);
    }
}
