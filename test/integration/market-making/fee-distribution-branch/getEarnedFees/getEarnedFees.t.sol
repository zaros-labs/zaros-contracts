// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";
import { Constants } from "@zaros/utils/Constants.sol";
import { Math } from "@zaros/utils/Math.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { sd59x18 } from "@prb-math/SD59x18.sol";

// Open Zeppelin dependencies
import { IERC20 } from "@openzeppelin/token/ERC20/IERC20.sol";

contract GetEarnedFees_Integration_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: address(users.owner.account) });
        createVaults(marketMakingEngine, INITIAL_VAULT_ID, FINAL_VAULT_ID);
        configureMarkets();
    }

    function testFuzz_WhenGetEarnedFeesIsCalled(
        uint256 vaultId,
        uint256 marketId,
        uint256 amountToDepositMarketFee,
        uint256 assetsToDepositVault
    )
        external
    {
        changePrank({ msgSender: address(perpsEngine) });

        uint128 uniswapV3StrategyId = 1;

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
            fuzzPerpMarketCreditConfig.marketId, address(usdc), uniswapV3StrategyId, bytes("")
        );

        changePrank({ msgSender: users.naruto.account });

        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        assetsToDepositVault =
            bound({ x: assetsToDepositVault, min: Constants.MIN_OF_SHARES_TO_STAKE, max: fuzzVaultConfig.depositCap });
        deal(fuzzVaultConfig.asset, users.naruto.account, assetsToDepositVault);

        marketMakingEngine.deposit(fuzzVaultConfig.vaultId, uint128(assetsToDepositVault), 0);

        uint256 sharesToStake = IERC20(fuzzVaultConfig.indexToken).balanceOf(users.naruto.account);

        marketMakingEngine.stake(fuzzVaultConfig.vaultId, uint128(sharesToStake), "", false);

        assertEq(IERC20(wEth).balanceOf(users.naruto.account), 0);

        uint256 expectedTokenAmount =
            uniswapV3Adapter.getExpectedOutput(address(usdc), address(wEth), amountToDepositMarketFee);
        uint256 amountOutMin = uniswapV3Adapter.calculateAmountOutMin(expectedTokenAmount);
        UD60x18 amountOutMinX18 = Math.convertTokenAmountToUd60x18(wEth.decimals(), amountOutMin);
        UD60x18 expectedWethRewardX18 = amountOutMinX18.mul(
            ud60x18(Constants.MAX_SHARES).sub(marketMakingEngine.exposed_getTotalFeeRecipientsShares())
        );

        // it should return the earned fees
        assertAlmostEq(
            marketMakingEngine.getEarnedFees(fuzzVaultConfig.vaultId, users.naruto.account),
            expectedWethRewardX18.intoUint256(),
            2,
            "the earned fees was returned incorrectly"
        );

        marketMakingEngine.claimFees(fuzzVaultConfig.vaultId);

        assertEq(
            marketMakingEngine.getEarnedFees(fuzzVaultConfig.vaultId, users.naruto.account),
            0,
            "the earned fees should be zero"
        );
    }
}
