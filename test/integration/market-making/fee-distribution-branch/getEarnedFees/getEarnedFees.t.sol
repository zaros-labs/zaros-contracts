// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { sd59x18 } from "@prb-math/SD59x18.sol";

contract MarketMaking_FeeDistribution_getEarnedFees is Base_Test {
    address actorOne = address(2);
    address actorTwo = address(3);
    bytes32 public actorId = bytes32(uint256(uint160(actorOne)));
    bytes32 public actorIdTwo = bytes32(uint256(uint160(actorTwo)));
    UD60x18 public actorOneShares = ud60x18(10e18);
    UD60x18 public actorTwoShares = ud60x18(30e18);
    int256 distributionValue = 200e18;

    function setUp() public virtual override {
        Base_Test.setUp();
        createVault();
        changePrank({ msgSender: users.naruto.account });
    }

    function test_GivenTheUserHasStaked() external {
        // set Actor Shares
        marketMakingEngine.exposed_setActorShares(1, actorId, actorOneShares);
        marketMakingEngine.exposed_setActorShares(1, actorIdTwo, actorTwoShares);
        // distribute fees for claim
        marketMakingEngine.exposed_distributeValue(1,sd59x18(distributionValue));
        // accumulate Actors accumulated fee earnings
        marketMakingEngine.exposed_accumulateActor(1, actorId);
        marketMakingEngine.exposed_accumulateActor(1, actorIdTwo);

        uint256 actorOneAccumulatedFees = 50e18;
        uint256 actorTwoAccumulatedFees = 150e18;

        // it should return fee amount
        assertEq(marketMakingEngine.getEarnedFees(1,actorOne), actorOneAccumulatedFees);
        assertEq(marketMakingEngine.getEarnedFees(1,actorTwo), actorTwoAccumulatedFees);
    }

    function test_GivenTheUserHasNotStaked() external {
        // it should return 0
        assertEq(marketMakingEngine.getEarnedFees(1,actorOne), 0);
    }
}
