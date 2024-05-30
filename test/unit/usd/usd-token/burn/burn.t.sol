// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { Base_Test } from "test/Base.t.sol";
import { USDToken } from "@zaros/usd/USDToken.sol";

contract USDToken_Burn_Test is Base_Test {
    USDToken token;

    function setUp() public virtual override {
        Base_Test.setUp();

        token = new USDToken(users.owner);
    }

    function test_RevertWhen_AmountIsZero() external {
        changePrank({ msgSender: users.owner });

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "amount") });

        token.burn(0);

        changePrank({ msgSender: users.naruto });

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "amount") });

        token.burn(0);
    }

    function testFuzz_WhenAmountIsNotZero(uint256 amount) external {
        amount = bound({ x: amount, min: 1, max: 100_000_000e18 });

        changePrank({ msgSender: users.owner });

        token.mint(users.owner, amount);
        token.mint(users.naruto, amount);

        assertEq(amount, token.balanceOf(users.owner), "amount is not correct");
        assertEq(amount, token.balanceOf(users.naruto), "amount is not correct");

        changePrank({ msgSender: users.naruto });
        token.burn(amount);

        changePrank({ msgSender: users.owner });
        token.burn(amount);

        // it should burn
        assertEq(0, token.balanceOf(users.owner), "amount is not correct");
        assertEq(0, token.balanceOf(users.naruto), "amount is not correct");
    }
}
