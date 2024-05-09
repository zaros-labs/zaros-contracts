// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

contract LiquidateAccounts_Integration_Test {
    function test_RevertGiven_TheSenderIsNotARegisteredLiquidator() external {
        // it should revert
    }

    modifier givenTheSenderIsARegisteredLiquidator() {
        _;
    }

    function test_WhenTheAccountsIdsArrayIsEmpty() external givenTheSenderIsARegisteredLiquidator {
        // it should return
    }

    modifier whenTheAccountsIdsArrayIsNotEmpty() {
        _;
    }

    function test_RevertGiven_OneOfTheAccountsDoesNotExist()
        external
        givenTheSenderIsARegisteredLiquidator
        whenTheAccountsIdsArrayIsNotEmpty
    {
        // it should revert
    }

    modifier givenAllAccountsExist() {
        _;
    }

    function test_RevertGiven_OneOfTheAccountsIsNotLiquidatable()
        external
        givenTheSenderIsARegisteredLiquidator
        whenTheAccountsIdsArrayIsNotEmpty
        givenAllAccountsExist
    {
        // it should revert
    }

    function test_GivenAllAccountsAreLiquidatable()
        external
        givenTheSenderIsARegisteredLiquidator
        whenTheAccountsIdsArrayIsNotEmpty
        givenAllAccountsExist
    {
        // it should clear any active market order
        // it should update each active market funding values
        // it should close all active positions
        // it should remove the account from all active markets
        // it should emit a {LogLiquidateAccount} event
    }
}
