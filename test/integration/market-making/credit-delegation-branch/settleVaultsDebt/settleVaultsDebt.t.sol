// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies test
import { Base_Test } from "test/Base.t.sol";

// Zaros dependencies source
import { Errors } from "@zaros/utils/Errors.sol";
import { Vault } from "@zaros/market-making/leaves/Vault.sol";

contract CreditDelegationBranch_SettleVaultsDebt_Integration_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        createVaults(marketMakingEngine, INITIAL_VAULT_ID, FINAL_VAULT_ID);
        configureMarkets();
        changePrank({ msgSender: users.naruto.account });
    }

    function test_RevertWhen_VaultIdIsInvalid() external {
        uint256[] memory invalidVaultIds = new uint256[](1);
        invalidVaultIds[0] = INVALID_VAULT_ID;

        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.VaultDoesNotExist.selector, INVALID_VAULT_ID));

        changePrank({ msgSender: address(perpsEngine) });
        marketMakingEngine.settleVaultsDebt(invalidVaultIds);
    }

    modifier whenVaultIdIsValid() {
        _;
    }

    function test_WhenVaultUnsettledRealizedDebtIsZero(
        uint256 vaultId,
        uint256 marketId
    )
        external
        whenVaultIdIsValid
    {
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);
        PerpMarketCreditConfig memory fuzzMarketConfig = getFuzzPerpMarketCreditConfig(marketId);

        uint256[] memory marketIds = new uint256[](1);
        marketIds[0] = fuzzMarketConfig.marketId;

        uint256[] memory vaultIds = new uint256[](1);
        vaultIds[0] = fuzzVaultConfig.vaultId;

        changePrank({ msgSender: users.owner.account });
        marketMakingEngine.connectVaultsAndMarkets(vaultIds, marketIds);

        deal({ token: address(fuzzVaultConfig.asset), to: fuzzVaultConfig.indexToken, give: 1e18 });

        marketMakingEngine.workaround_updateMarketTotalDelegatedCreditUsd(fuzzMarketConfig.marketId, 1e10);
        marketMakingEngine.workaround_Vault_setTotalCreditDelegationWeight(fuzzVaultConfig.vaultId, 1e9);

        // it should continue

        changePrank({ msgSender: address(perpsEngine) });
        marketMakingEngine.settleVaultsDebt(vaultIds);
    }

    function test_WhenTheVaultUnsettledRealizedDebtIsLessThanZero(
        uint256 vaultId,
        uint256 marketId
    )
        external
        whenVaultIdIsValid
    {
        vm.skip(true);
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);
        PerpMarketCreditConfig memory fuzzPerpMarketCreditConfig = getFuzzPerpMarketCreditConfig(marketId);
        uint256[] memory marketIds = new uint256[](1);
        marketIds[0] = fuzzPerpMarketCreditConfig.marketId;

        uint256[] memory vaultIds = new uint256[](1);
        vaultIds[0] = fuzzVaultConfig.vaultId;

        changePrank({ msgSender: users.owner.account });
        marketMakingEngine.connectVaultsAndMarkets(vaultIds, marketIds);

        deal({ token: address(fuzzVaultConfig.asset), to: fuzzVaultConfig.indexToken, give: 1e18 });

        marketMakingEngine.workaround_updateMarketTotalDelegatedCreditUsd(fuzzPerpMarketCreditConfig.marketId, 1e10);
        marketMakingEngine.workaround_Vault_setTotalCreditDelegationWeight(fuzzVaultConfig.vaultId, 1e9);

        // it should emit { LogSettleVaultDebt } event
        // vm.expectEmit();
        // emit Vault.LogUpdateVaultCreditCapacity(fuzzVaultConfig.vaultId, 0, 0, 0 ,0 ,0);

        // it should increase the usdc available for engine amount
    }

    function test_WhenTheVaultUnsettledRealizedDebtIsGreaterThanZero() external whenVaultIdIsValid {
        // it should emit { LogSettleVaultDebt } event
        // it should decrease vault deposited usd amount
    }
}
