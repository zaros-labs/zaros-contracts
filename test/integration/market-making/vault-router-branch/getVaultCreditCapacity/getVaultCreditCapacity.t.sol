// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";

contract GetVaultCreditCapacity_Integration_Test is Base_Test {

    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        createVaults(marketMakingEngine, INITIAL_VAULT_ID, FINAL_VAULT_ID, true, address(perpsEngine));
        configureMarkets();
        changePrank({ msgSender: users.naruto.account });
    }

    function testFuzz_WhenGetVaultCreditCapacityIsCalled(uint256 vaultId, uint256 assetsToDeposit) external {
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        // perform the deposit
        assetsToDeposit = bound({ x: assetsToDeposit, min: 1e6, max: fuzzVaultConfig.depositCap });
        address user = users.naruto.account;
        fundUserAndDepositInVault(user, fuzzVaultConfig.vaultId, uint128(assetsToDeposit));

        // it should return the vault credit capacity
        marketMakingEngine.getVaultCreditCapacity(fuzzVaultConfig.vaultId);
    }
}
