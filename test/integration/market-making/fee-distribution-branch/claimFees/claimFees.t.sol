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
        createVaults(marketMakingEngine, INITIAL_VAULT_ID, FINAL_VAULT_ID);
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

    // TODO: Add the rest of the test cases
    function testFuzz_WhenAmountToClaimIsGreaterThenZero(
        uint256 vaultId,
        uint256 marketId,
        uint256 amountToDepositMarketFee,
        uint256 assetsToDepositVault
    )
        external
        whenTheUserDoesHaveAvailableShares
    {
        // changePrank({ msgSender: address(perpsEngine) });

        // uint128 uniswapV3StrategyId = 1;

        // PerpMarketCreditConfig memory fuzzPerpMarketCreditConfig = getFuzzPerpMarketCreditConfig(marketId);

        // amountToDepositMarketFee = bound({
        //     x: amountToDepositMarketFee,
        //     min: USDC_MIN_DEPOSIT_MARGIN,
        //     max: convertUd60x18ToTokenAmount(address(usdc), USDC_DEPOSIT_CAP_X18)
        // });

        // deal({ token: address(usdc), to: address(perpsEngine), give: amountToDepositMarketFee });

        // marketMakingEngine.receiveMarketFee(fuzzPerpMarketCreditConfig.marketId, address(usdc),
        // amountToDepositMarketFee);

        // marketMakingEngine.convertAccumulatedFeesToWeth(
        //     fuzzPerpMarketCreditConfig.marketId, address(usdc), uniswapV3StrategyId
        // );

        // changePrank({ msgSender: users.naruto.account });

        // VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        // assetsToDepositVault = bound({ x: assetsToDepositVault, min: 1, max: fuzzVaultConfig.depositCap });
        // deal(fuzzVaultConfig.asset, users.naruto.account, assetsToDepositVault);

        // marketMakingEngine.deposit(fuzzVaultConfig.vaultId, uint128(assetsToDepositVault), 0);

        // marketMakingEngine.claimFees(fuzzVaultConfig.vaultId);

        // it should update accumulate actor
        // it should transfer the fees to the sender
        // it should emit {LogClaimFees} event
    }
}
