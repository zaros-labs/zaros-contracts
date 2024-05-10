// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Integration_Shared_Test } from "test/integration/shared/BaseIntegration.t.sol";
import { Errors } from "@zaros/utils/Errors.sol";

contract LiquidateAccounts_Integration_Test is Base_Integration_Shared_Test {
    function setUp() public override {
        Base_Integration_Shared_Test.setUp();
        changePrank({ msgSender: users.owner });
        configureSystemParameters();

        createPerpMarkets();

        changePrank({ msgSender: users.naruto });
    }

    function test_RevertGiven_TheSenderIsNotARegisteredLiquidator() external {
        uint128[] memory accountsIds = new uint128[](1);

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.LiquidatorNotRegistered.selector, users.naruto) });
        perpsEngine.liquidateAccounts({
            accountsIds: accountsIds,
            marginCollateralRecipient: users.marginCollateralRecipient,
            liquidationFeeRecipient: users.settlementFeeRecipient
        });
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
