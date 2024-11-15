// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";
import { Errors } from "@zaros/utils/Errors.sol";

contract CreditDelegationBranch_GetAdjustedProfitForMarketId_Integration_Test is Base_Test {
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

    modifier givenTheSenderIsTheRegisteredEngine() {
        _;
    }

    // TODO
    function test_RevertWhen_TheAmountIsZero() external givenTheSenderIsTheRegisteredEngine {
        // it should revert
    }

    modifier whenTheAmountIsNotZero() {
        _;
    }

    // TODO
    function test_RevertWhen_TheCollateralIsNotEnabled()
        external
        givenTheSenderIsTheRegisteredEngine
        whenTheAmountIsNotZero
    {
        // it should revert
    }

    modifier whenTheCollateralIsEnabled() {
        _;
    }

    // TODO
    function test_RevertWhen_TheMarketIsNotLive()
        external
        givenTheSenderIsTheRegisteredEngine
        whenTheAmountIsNotZero
        whenTheCollateralIsEnabled
    {
        // it should revert
    }

    modifier whenTheMarketIsLive() {
        _;
    }

    // TODO
    function test_RevertWhen_TheTotalDelegatedCreditUsdIsZero()
        external
        givenTheSenderIsTheRegisteredEngine
        whenTheAmountIsNotZero
        whenTheCollateralIsEnabled
        whenTheMarketIsLive
    {
        // it should revert
    }

    // TODO
    function test_WhenTheTotalDelegatedCreditUsdIsGreaterThanZero()
        external
        givenTheSenderIsTheRegisteredEngine
        whenTheAmountIsNotZero
        whenTheCollateralIsEnabled
        whenTheMarketIsLive
    {
        // it should depoit credit for market
        // it should emit {LogDepositCreditForMarket} event
    }
}
