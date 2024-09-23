// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { sd59x18 } from "@prb-math/SD59x18.sol";

contract GetEarnedFees_Integration_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        createVaults(marketMakingEngine, INITIAL_VAULT_ID, FINAL_VAULT_ID);
        changePrank({ msgSender: users.naruto.account });
    }

    function test_GivenTheUserHasStaked() external {
        // set Actor Shares
        marketMakingEngine.exposed_setActorShares(
            1, 
            bytes32(uint256(uint160(address(users.naruto.account)))), 
            ud60x18(10e18)
        );
        marketMakingEngine.exposed_setActorShares(
            1, 
            bytes32(uint256(uint160(address(users.sasuke.account)))), 
            ud60x18(30e18)
        );
        // distribute fees for claim at
        marketMakingEngine.exposed_distributeValue(1,sd59x18(200e18));
        // accumulate Actors accumulated fee earnings
        marketMakingEngine.exposed_accumulateActor(1, bytes32(uint256(uint160(address(users.naruto.account)))));
        marketMakingEngine.exposed_accumulateActor(1, bytes32(uint256(uint160(address(users.sasuke.account)))));

        uint256 actorOneAccumulatedFees = 50e18;
        uint256 actorTwoAccumulatedFees = 150e18;

        // it should return fee amount
        assertEq(marketMakingEngine.getEarnedFees(1, users.naruto.account), actorOneAccumulatedFees);
        assertEq(marketMakingEngine.getEarnedFees(1, users.sasuke.account), actorTwoAccumulatedFees);
    }

    function test_GivenTheUserHasNotStaked() external {
        // it should return 0
        assertEq(marketMakingEngine.getEarnedFees(1,users.naruto.account), 0);
    }
}
