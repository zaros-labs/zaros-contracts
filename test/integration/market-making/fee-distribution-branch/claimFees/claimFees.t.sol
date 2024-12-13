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

    struct ClaimFeesState {
        // asset balances
        uint256 stakerAssetBal;
        uint256 vaultAssetBal;
        uint256 marketEngineAssetBal;
        // vault balances
        uint128 stakerVaultBal;
        uint128 marketEngineVaultBal;
        // Distribution stake total balances
        uint128 totalShares;
        int128 valuePerShare;
        // Distribution stake individual balances
        uint128 stakerShares;
        int128 stakerLastValuePerShare;
    }

    function _getClaimFeesState(
        address staker,
        uint128 vaultId,
        IERC20 assetToken,
        IERC20 vault
    )
        internal
        view
        returns (ClaimFeesState memory state)
    {
        state.stakerAssetBal = assetToken.balanceOf(staker);
        state.vaultAssetBal = assetToken.balanceOf(address(vault));
        state.marketEngineAssetBal = assetToken.balanceOf(address(marketMakingEngine));

        state.stakerVaultBal = uint128(vault.balanceOf(staker));
        state.marketEngineVaultBal = uint128(vault.balanceOf(address(marketMakingEngine)));

        (state.totalShares, state.valuePerShare, state.stakerShares, state.stakerLastValuePerShare) =
            marketMakingEngine.getTotalAndAccountStakingData(vaultId, staker);
    }

    // only for WETH vault & associated market at the moment
    function testFuzz_stakerClaimsEarnedFees(uint128 assetsToDeposit, uint128 marketFees) external {
        // ensure valid vault and load vault config
        uint128 vaultId = WETH_CORE_VAULT_ID;
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        // ensure valid deposit amount and perform the deposit
        address user = users.naruto.account;
        assetsToDeposit =
            uint128(bound(assetsToDeposit, calculateMinOfSharesToStake(vaultId), fuzzVaultConfig.depositCap/2));
        fundUserAndDepositInVault(user, vaultId, assetsToDeposit);

        // save and verify pre stake state
        ClaimFeesState memory preStakeState =
            _getClaimFeesState(user, vaultId, IERC20(fuzzVaultConfig.asset), IERC20(fuzzVaultConfig.indexToken));
        assertGt(preStakeState.stakerVaultBal, 0, "Staker vault balance > 0 after deposit");

        // perform the stake
        vm.startPrank(user);
        marketMakingEngine.stake(vaultId, preStakeState.stakerVaultBal);

        // save and verify post stake state
        ClaimFeesState memory postStakeState =
            _getClaimFeesState(user, vaultId, IERC20(fuzzVaultConfig.asset), IERC20(fuzzVaultConfig.indexToken));
        assertEq(postStakeState.stakerVaultBal, 0, "Staker has no vault shares after staking them");
        assertEq(
            postStakeState.marketEngineVaultBal,
            preStakeState.stakerVaultBal,
            "MarketEngine received stakers vault shares"
        );
        assertEq(
            postStakeState.totalShares, preStakeState.stakerVaultBal, "Staking totalShares == staked vault balance"
        );
        assertEq(postStakeState.valuePerShare, 0, "Staking valuePerShare 0 as no value distributed");
        assertEq(postStakeState.stakerShares, preStakeState.stakerVaultBal, "Staker shares == staked vault balance");
        assertEq(postStakeState.stakerLastValuePerShare, 0, "Staker has no value per share as no value distributed");

        // sent WETH market fees from PerpsEngine -> MarketEngine
        marketFees = uint128(bound(marketFees, calculateMinOfSharesToStake(vaultId), fuzzVaultConfig.depositCap/2));
        deal(fuzzVaultConfig.asset, address(perpsEngine), marketFees);
        changePrank({ msgSender: address(perpsEngine) });
        vm.expectEmit({ emitter: address(marketMakingEngine) });
        emit FeeDistributionBranch.LogReceiveMarketFee(fuzzVaultConfig.asset, ETH_USD_MARKET_ID, marketFees);
        marketMakingEngine.receiveMarketFee(ETH_USD_MARKET_ID, fuzzVaultConfig.asset, marketFees);
        assertEq(IERC20(fuzzVaultConfig.asset).balanceOf(address(marketMakingEngine)), marketFees);

        // verify the staker has earned rewards which are not yet claimed
        uint256 stakerEarnedFees = marketMakingEngine.getEarnedFees(vaultId, user);
        assertGt(stakerEarnedFees, 0, "Staker has earned fees");
        assertEq(IERC20(fuzzVaultConfig.asset).balanceOf(user), 0, "Staker has no asset tokens prior to unstake");

        // staker claims rewards
        changePrank({ msgSender: user });
        marketMakingEngine.claimFees(vaultId);

        // save and verify post claim fees state
        ClaimFeesState memory postClaimFeesState =
            _getClaimFeesState(user, vaultId, IERC20(fuzzVaultConfig.asset), IERC20(fuzzVaultConfig.indexToken));
        assertEq(
            postClaimFeesState.stakerAssetBal,
            stakerEarnedFees,
            "Staker received asset tokens after claiming fees"
        );

        // attempting to claim again fails
        vm.expectRevert(Errors.NoFeesToClaim.selector);
        marketMakingEngine.claimFees(vaultId);
    }
}
