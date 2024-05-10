// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { LiquidationBranch_Integration_Test } from "../LiquidationBranchIntegration.t.sol";
import { Errors } from "@zaros/utils/Errors.sol";

contract LiquidateAccounts_Integration_Test is LiquidationBranch_Integration_Test {
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
        uint128[] memory accountsIds;

        changePrank({ msgSender: liquidationKeeper });

        // it should return
        perpsEngine.liquidateAccounts({
            accountsIds: accountsIds,
            marginCollateralRecipient: users.marginCollateralRecipient,
            liquidationFeeRecipient: users.settlementFeeRecipient
        });
    }

    modifier whenTheAccountsIdsArrayIsNotEmpty() {
        _;
    }

    function test_RevertGiven_OneOfTheAccountsDoesNotExist()
        external
        givenTheSenderIsARegisteredLiquidator
        whenTheAccountsIdsArrayIsNotEmpty
    {
        uint128[] memory accountsIds = new uint128[](1);
        accountsIds[0] = 1;

        changePrank({ msgSender: liquidationKeeper });

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.AccountNotFound.selector, accountsIds[0], liquidationKeeper) });
        perpsEngine.liquidateAccounts({
            accountsIds: accountsIds,
            marginCollateralRecipient: users.marginCollateralRecipient,
            liquidationFeeRecipient: users.settlementFeeRecipient
        });
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
