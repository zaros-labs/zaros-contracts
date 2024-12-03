// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";
import { Errors } from "@zaros/utils/Errors.sol";

contract CreditDelegationBranch_WithdrawUsdTokenFromMarket_Integration_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        createVaults(marketMakingEngine, INITIAL_VAULT_ID, FINAL_VAULT_ID);
        configureMarkets();
    }

    // TODO
    function test_RevertGiven_TheSenderIsNotTheRegisteredEngine() external {
        // it should revert
    }

    // TODO
    modifier givenTheSenderIsTheRegisteredEngine() {
        _;
    }

    // TODO
    function test_RevertWhen_TheMarketIsNotLive() external givenTheSenderIsTheRegisteredEngine {
        // it should revert
    }

    modifier whenTheMarketIsLive() {
        _;
    }

    // TODO
    function test_RevertWhen_TheCreditCapacityUsdIsLessThanZero()
        external
        givenTheSenderIsTheRegisteredEngine
        whenTheMarketIsLive
    {
        // it should revert
    }

    // TODO
    function test_WhenTheCreditCapacityUsdIsEqualOrGreaterThanZero()
        external
        givenTheSenderIsTheRegisteredEngine
        whenTheMarketIsLive
    {
        // it should mint the usd token
        // it should emit {LogWithdrawUsdTokenFromMarket} event
    }
}
