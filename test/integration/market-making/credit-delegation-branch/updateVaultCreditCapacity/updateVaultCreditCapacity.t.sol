// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";
import { Errors } from "@zaros/utils/Errors.sol";

contract CreditDelegationBranch_UpdateVaultCreditCapacity_Integration_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        createVaults(marketMakingEngine, INITIAL_VAULT_ID, FINAL_VAULT_ID);
        configureMarkets();
    }

    // TODO
    function test_GivenTheUpdateVaultCreditCapacityIsCalled() external {
        // it should recalculate the vault credit capacity
    }
}
