// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";
import { Errors } from "@zaros/utils/Errors.sol";

// PRB Math dependencies
import { ud60x18 } from "@prb-math/UD60x18.sol";
import { sd59x18 } from "@prb-math/SD59x18.sol";

contract ClaimFees_Integration_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: address(users.owner.account) });
        configureMarkets();
    }

    function testFuzz_RevertWhen_TheUserDoesNotHaveAvailableShares(
        uint256 vaultId,
        uint256 assetsToDeposit
    )
        external
    {
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        assetsToDeposit = bound({ x: assetsToDeposit, min: 1, max: fuzzVaultConfig.depositCap });
        deal(fuzzVaultConfig.asset, users.naruto.account, assetsToDeposit);

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.NoSharesAvailable.selector) });

        marketMakingEngine.claimFees(fuzzVaultConfig.vaultId);
    }

    modifier whenTheUserDoesHaveAvailableShares() {
        _;
    }

    function testFuzz_RevertWhen_AmountToClaimIsZero() external whenTheUserDoesHaveAvailableShares {
        // it should revert
    }

    function testFuzz_WhenAmountToClaimIsGreaterThenZero() external whenTheUserDoesHaveAvailableShares {
        // it should update accumulate actor
        // it should transfer the fees to the sender
        // it should emit {LogClaimFees} event
    }
}
