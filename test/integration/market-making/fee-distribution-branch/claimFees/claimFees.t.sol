// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { Constants } from "@zaros/utils/Constants.sol";
import { Math } from "@zaros/utils/Math.sol";
import { FeeDistributionBranch } from "@zaros/market-making/branches/FeeDistributionBranch.sol";
import { IDexAdapter } from "@zaros/utils/interfaces/IDexAdapter.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { sd59x18 } from "@prb-math/SD59x18.sol";

// Open Zeppelin dependencies
import { IERC20 } from "@openzeppelin/token/ERC20/IERC20.sol";

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

    function testFuzz_RevertWhen_AmountToClaimIsZero(
        uint256 vaultId,
        uint256 assetsToDepositVault
    )
        external
        whenTheUserDoesHaveAvailableShares
    {
        changePrank({ msgSender: users.naruto.account });

        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        assetsToDepositVault = bound({
            x: assetsToDepositVault,
            min: calculateMinOfSharesToStake(fuzzVaultConfig.vaultId),
            max: fuzzVaultConfig.depositCap
        });
        deal(fuzzVaultConfig.asset, users.naruto.account, assetsToDepositVault);

        marketMakingEngine.deposit(fuzzVaultConfig.vaultId, uint128(assetsToDepositVault), 0, "", false);

        uint256 sharesToStake = IERC20(fuzzVaultConfig.indexToken).balanceOf(users.naruto.account);

        marketMakingEngine.stake(fuzzVaultConfig.vaultId, uint128(sharesToStake));

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.NoFeesToClaim.selector) });

        marketMakingEngine.claimFees(fuzzVaultConfig.vaultId);
    }

    function testFuzz_WhenAmountToClaimIsGreaterThenZero(
        uint256 vaultId,
        uint256 marketId,
        uint256 amountToDepositMarketFee,
        uint256 assetsToDepositVault,
        uint256 adapterIndex
    )
        external
        whenTheUserDoesHaveAvailableShares
    {
        changePrank({ msgSender: address(perpsEngine) });

        IDexAdapter adapter = getFuzzDexAdapter(adapterIndex);

        PerpMarketCreditConfig memory fuzzPerpMarketCreditConfig = getFuzzPerpMarketCreditConfig(marketId);

        amountToDepositMarketFee = bound({
            x: amountToDepositMarketFee,
            min: USDC_MIN_DEPOSIT_MARGIN,
            max: convertUd60x18ToTokenAmount(address(usdc), USDC_DEPOSIT_CAP_X18)
        });

        deal({ token: address(usdc), to: address(perpsEngine), give: amountToDepositMarketFee });

        marketMakingEngine.receiveMarketFee(
            fuzzPerpMarketCreditConfig.marketId, address(usdc), amountToDepositMarketFee
        );

        marketMakingEngine.convertAccumulatedFeesToWeth(
            fuzzPerpMarketCreditConfig.marketId, address(usdc), adapter.STRATEGY_ID(), bytes("")
        );

        changePrank({ msgSender: users.naruto.account });

        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        assetsToDepositVault = bound({
            x: assetsToDepositVault,
            min: calculateMinOfSharesToStake(fuzzVaultConfig.vaultId),
            max: fuzzVaultConfig.depositCap
        });
        deal(fuzzVaultConfig.asset, users.naruto.account, assetsToDepositVault);

        marketMakingEngine.deposit(fuzzVaultConfig.vaultId, uint128(assetsToDepositVault), 0, "", false);

        uint256 sharesToStake = IERC20(fuzzVaultConfig.indexToken).balanceOf(users.naruto.account);

        marketMakingEngine.stake(fuzzVaultConfig.vaultId, uint128(sharesToStake));

        assertEq(IERC20(wEth).balanceOf(users.naruto.account), 0);

        uint256 earnedFees = marketMakingEngine.getEarnedFees(fuzzVaultConfig.vaultId, users.naruto.account);

        // it should emit {LogClaimFees} event
        vm.expectEmit({ emitter: address(marketMakingEngine) });
        emit FeeDistributionBranch.LogClaimFees(users.naruto.account, fuzzVaultConfig.vaultId, earnedFees);

        marketMakingEngine.claimFees(fuzzVaultConfig.vaultId);

        uint256 amountUserFeesReceived = IERC20(wEth).balanceOf(users.naruto.account);

        // it should transfer the fees to the sender
        uint256 expectedTokenAmount =
            adapter.getExpectedOutput(address(usdc), address(wEth), amountToDepositMarketFee);
        uint256 amountOutMin = adapter.calculateAmountOutMin(expectedTokenAmount);
        UD60x18 amountOutMinX18 = Math.convertTokenAmountToUd60x18(wEth.decimals(), amountOutMin);
        UD60x18 expectedWethRewardX18 = amountOutMinX18.mul(
            ud60x18(Constants.MAX_SHARES).sub(ud60x18(marketMakingEngine.exposed_getTotalFeeRecipientsShares()))
        );
        assertAlmostEq(
            amountUserFeesReceived,
            expectedWethRewardX18.intoUint256(),
            2,
            "the user should have the expected wEth reward"
        );

        // it should update accumulate actor
        earnedFees = marketMakingEngine.getEarnedFees(fuzzVaultConfig.vaultId, users.naruto.account);
        assertEq(earnedFees, 0, "the user should have zero fees to claim");
    }
}
