// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";
import { Errors } from "@zaros/utils/Errors.sol";

// PRB Math dependencies
import { ud60x18 } from "@prb-math/UD60x18.sol";
import { sd59x18 } from "@prb-math/SD59x18.sol";

contract GetEarnedFees_Integration_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        createVaults(marketMakingEngine, INITIAL_VAULT_ID, FINAL_VAULT_ID);
        changePrank({ msgSender: users.naruto.account });
    }

    function test_RevertWhen_VaultDoesNotExist() external {
        // it should revert
        // vm.expectRevert(abi.encodeWithSelector(Errors.VaultDoesNotExist.selector));
        // marketMakingEngine.getEarnedFees(INVALID_VAULT_ID, users.naruto.account);
    }

    modifier whenVaultDoesExist() {
        _;
    }

    function test_GivenTheUserHasStaked() external whenVaultDoesExist {
        uint256 actorOneShares = 10e18;
        uint256 actorTwoShares = 30e18;

        // set Actor Shares
        marketMakingEngine.exposed_setActorShares(
            FINAL_VAULT_ID,
            bytes32(uint256(uint160(address(users.naruto.account)))),
            ud60x18(actorOneShares)
        );
        marketMakingEngine.exposed_setActorShares(
            FINAL_VAULT_ID,
            bytes32(uint256(uint160(address(users.sasuke.account)))),
            ud60x18(actorTwoShares)
        );

        int256 distributedAmount = 200e18;

        // distribute fees for claim at
        marketMakingEngine.exposed_distributeValue(FINAL_VAULT_ID, sd59x18(distributedAmount));

        uint256 actorOneAccumulatedFees = 50e18;
        uint256 actorTwoAccumulatedFees = 150e18;

        // it should return fee amount
        assertEq(marketMakingEngine.getEarnedFees(FINAL_VAULT_ID, users.naruto.account), actorOneAccumulatedFees);
        assertEq(marketMakingEngine.getEarnedFees(FINAL_VAULT_ID, users.sasuke.account), actorTwoAccumulatedFees);
    }

    function test_GivenTheUserHasNotStaked() external whenVaultDoesExist {
        uint256 zeroAmount = 0;
        // it should return 0
        assertEq(marketMakingEngine.getEarnedFees(FINAL_VAULT_ID,users.naruto.account), zeroAmount);
    }
}
