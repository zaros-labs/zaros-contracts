// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";
import { Errors } from "@zaros/utils/Errors.sol";

contract CreditDelegationBranch_GetAdjustedProfitForMarketId_Integration_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        createVaults(marketMakingEngine, INITIAL_VAULT_ID, FINAL_VAULT_ID, true, address(perpsEngine));
        configureMarkets();
    }

    // TODO
    function test_RevertWhen_TheMarketIsNotLive() external {
        // it should revert
    }

    modifier whenTheMarketIsLive() {
        _;
    }

    // TODO
    function test_RevertWhen_TheCreditCapacityIsLessThanOrEqualToZero() external whenTheMarketIsLive {
        // it should revert
    }

    // TODO
    function test_WhenTheCreditCapacityIsGreaterThanZero() external whenTheMarketIsLive {
        // it should return the adjusted profit
    }
}
