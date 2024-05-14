// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { Base_Integration_Shared_Test } from "test/integration/shared/BaseIntegration.t.sol";
import { IPerpsEngine } from "@zaros/perpetuals/PerpsEngine.sol";

contract MarketOrderKeeper_Integration_Test is Base_Integration_Shared_Test{
    function setUp() public override {
        Base_Integration_Shared_Test.setUp();
        changePrank({ msgSender: users.owner });
        configureSystemParameters();

        createPerpMarkets();

        changePrank({ msgSender: users.naruto });
    }

    modifier givenInitializeContract() {
        _;
    }

    function test_GivenCallCheckCallbackFunction() external givenInitializeContract {
        // TODO
        // it should return upkeepNeeded
        // it should return performData
    }
}
