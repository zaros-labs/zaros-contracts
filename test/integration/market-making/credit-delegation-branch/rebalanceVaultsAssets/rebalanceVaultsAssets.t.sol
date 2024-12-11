// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";

contract CreditDelegationBranch_RebalanceVaultsAssets_Integration_Test is Base_Test {
    function test_RevertWhen_TheIndebtVaultAndIncreditVaultsEnginesMismatch() external {
        // it should revert
    }

    modifier whenTheIndebtVaultAndIncreditVaultsEnginesMatch() {
        _;
    }

    function test_RevertWhen_TheIncreditVaultUnsettledRealizedDebtIsLessThanZero()
        external
        whenTheIndebtVaultAndIncreditVaultsEnginesMatch
    {
        // it should revert
    }

    modifier whenTheIncreditVaultUnsettledRealizedDebtIsMoreThanZero() {
        _;
    }

    function test_RevertWhen_TheIndebtVaultUnsettledRealizedDebtIsMoreThanOrEqualToZero()
        external
        whenTheIndebtVaultAndIncreditVaultsEnginesMatch
        whenTheIncreditVaultUnsettledRealizedDebtIsMoreThanZero
    {
        // it should revert
    }

    function test_WhenTheIndebtVaultUnsettledRealizedDebtIsLessThanZero()
        external
        whenTheIndebtVaultAndIncreditVaultsEnginesMatch
        whenTheIncreditVaultUnsettledRealizedDebtIsMoreThanZero
    {
        // it should emit { LogRebalanceVaultsAssets } event
        // it should update vaults deposited usd and markets realized debt
    }
}
