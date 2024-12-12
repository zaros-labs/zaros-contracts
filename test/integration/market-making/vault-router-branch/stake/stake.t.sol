// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import { console } from "forge-std/console.sol";

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";
import { FeeDistributionBranch } from "@zaros/market-making/branches/FeeDistributionBranch.sol";

// Open Zeppelin dependencies
import { IERC20 } from "@openzeppelin/token/ERC20/IERC20.sol";

contract Stake_Integration_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        createVaults(marketMakingEngine, INITIAL_VAULT_ID, FINAL_VAULT_ID);
        configureMarkets();
        changePrank({ msgSender: users.naruto.account });
    }

    function testFuzz_RevertWhen_VaultIsInvalid(uint128 sharesToStake) external {
        // it should revert
        vm.expectRevert();
        marketMakingEngine.stake(INVALID_VAULT_ID, sharesToStake);
    }

    modifier whenVaultIdIsValid() {
        _;
    }

    struct StakeState {
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

    function _getStakeState(
        address staker,
        uint128 vaultId,
        IERC20 vault
    )
        internal
        view
        returns (StakeState memory state)
    {
        state.stakerVaultBal = uint128(vault.balanceOf(staker));
        state.marketEngineVaultBal = uint128(vault.balanceOf(address(marketMakingEngine)));

        (state.totalShares, state.valuePerShare, state.stakerShares, state.stakerLastValuePerShare) =
            marketMakingEngine.getTotalAndAccountStakingData(vaultId, staker);
    }

    function testFuzz_WhenUserHasShares(uint128 vaultId, uint128 assetsToDeposit) external whenVaultIdIsValid {
        // ensure valid vault and load vault config
        vaultId = uint128(bound(vaultId, INITIAL_VAULT_ID, FINAL_VAULT_ID));
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        // ensure valid deposit amount and perform the deposit
        address user = users.naruto.account;
        assetsToDeposit =
            uint128(bound(assetsToDeposit, calculateMinOfSharesToStake(vaultId), fuzzVaultConfig.depositCap));
        fundUserAndDepositInVault(user, vaultId, assetsToDeposit);

        // save and verify pre state
        StakeState memory pre = _getStakeState(user, vaultId, IERC20(fuzzVaultConfig.indexToken));
        assertGt(pre.stakerVaultBal, 0, "Staker vault balance > 0 after deposit");
        assertEq(pre.marketEngineVaultBal, 0, "MarketEngine has no vault shares");
        assertEq(pre.totalShares, 0, "Staking totalShares 0 as no stakers");
        assertEq(pre.valuePerShare, 0, "Staking valuePerShare 0 as no stakers and no value distributed");
        assertEq(pre.stakerShares, 0, "Staker has no staking shares prior to staking");
        assertEq(pre.stakerLastValuePerShare, 0, "Staker has no value per share prior to staking");

        // perform the stake
        vm.startPrank(user);
        marketMakingEngine.stake(vaultId, pre.stakerVaultBal);

        // save and verify post state
        StakeState memory post = _getStakeState(user, vaultId, IERC20(fuzzVaultConfig.indexToken));
        assertEq(post.stakerVaultBal, 0, "Staker has no vault shares after staking them");
        assertEq(post.marketEngineVaultBal, pre.stakerVaultBal, "MarketEngine received stakers vault shares");
        assertEq(post.totalShares, pre.stakerVaultBal, "Staking totalShares == staked vault balance");
        assertEq(post.valuePerShare, 0, "Staking valuePerShare 0 as no value distributed");
        assertEq(post.stakerShares, pre.stakerVaultBal, "Staker shares == staked vault balance");
        assertEq(post.stakerLastValuePerShare, 0, "Staker has no value per share as no value distributed");
    }

    modifier whenTheUserHasAReferralCode() {
        _;
    }

    modifier whenTheReferralCodeIsCustom() {
        _;
    }

    function test_RevertWhen_TheReferralCodeIsInvalid()
        external
        whenVaultIdIsValid
        whenTheUserHasAReferralCode
        whenTheReferralCodeIsCustom
    {
        // it should revert
    }

    function test_WhenTheReferralCodeIsValid() external whenTheUserHasAReferralCode whenTheReferralCodeIsCustom {
        // it should emit {LogReferralSet} event
    }

    modifier whenTheReferralCodeIsNotCustom() {
        _;
    }

    function test_RevertWhen_TheReferralCodeIsEqualToMsgSender()
        external
        whenVaultIdIsValid
        whenTheUserHasAReferralCode
        whenTheReferralCodeIsNotCustom
    {
        // it should revert
    }

    function test_WhenTheReferralCodeIsNotEqualToMsgSender()
        external
        whenVaultIdIsValid
        whenTheUserHasAReferralCode
        whenTheReferralCodeIsNotCustom
    {
        // it should emit {LogReferralSet} event
    }

    function test_stakerMissesRewards() external {
        // ensure valid vault and load vault config
        uint128 vaultId = WETH_CORE_VAULT_ID;
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        // ensure valid deposit amount and perform the deposit
        address user = users.naruto.account;
        uint128 assetsToDeposit = uint128(calculateMinOfSharesToStake(vaultId));
        fundUserAndDepositInVault(user, vaultId, assetsToDeposit);

        // save and verify pre state
        StakeState memory pre1 = _getStakeState(user, vaultId, IERC20(fuzzVaultConfig.indexToken));
        assertGt(pre1.stakerVaultBal, 0, "Staker vault balance > 0 after deposit");
        assertEq(pre1.marketEngineVaultBal, 0, "MarketEngine has no vault shares");
        assertEq(pre1.totalShares, 0, "Staking totalShares 0 as no stakers");
        assertEq(pre1.valuePerShare, 0, "Staking valuePerShare 0 as no stakers and no value distributed");
        assertEq(pre1.stakerShares, 0, "Staker has no staking shares prior to staking");
        assertEq(pre1.stakerLastValuePerShare, 0, "Staker has no value per share prior to staking");

        // perform the stake
        vm.startPrank(user);
        marketMakingEngine.stake(vaultId, pre1.stakerVaultBal);

        // save and verify post state
        StakeState memory post1 = _getStakeState(user, vaultId, IERC20(fuzzVaultConfig.indexToken));
        assertEq(post1.stakerVaultBal, 0, "Staker has no vault shares after staking them");
        assertEq(post1.marketEngineVaultBal, pre1.stakerVaultBal, "MarketEngine received stakers vault shares");

        assertEq(post1.totalShares, pre1.stakerVaultBal, "Staking totalShares == staked vault balance");
        assertEq(post1.valuePerShare, 0, "Staking valuePerShare 0 as no value distributed");
        assertEq(post1.stakerShares, pre1.stakerVaultBal, "Staker shares == staked vault balance");
        assertEq(post1.stakerLastValuePerShare, 0, "Staker has no value per share as no value distributed");

        // sent WETH market fees from PerpsEngine -> MarketEngine
        uint256 marketFees = 1e18;
        deal(fuzzVaultConfig.asset, address(perpsEngine), marketFees);
        changePrank({ msgSender: address(perpsEngine) });
        vm.expectEmit({ emitter: address(marketMakingEngine) });
        emit FeeDistributionBranch.LogReceiveMarketFee(fuzzVaultConfig.asset, ETH_USD_MARKET_ID, marketFees);
        marketMakingEngine.receiveMarketFee(ETH_USD_MARKET_ID, fuzzVaultConfig.asset, marketFees);
        assertEq(IERC20(fuzzVaultConfig.asset).balanceOf(address(marketMakingEngine)), marketFees);

        // have to call this function first before they can be used for rewards
        marketMakingEngine.convertAccumulatedFeesToWeth(ETH_USD_MARKET_ID, fuzzVaultConfig.asset, 0, "");

        StakeState memory post2 = _getStakeState(user, vaultId, IERC20(fuzzVaultConfig.indexToken));
        assertEq(post2.stakerVaultBal, 0, "Staker has no vault shares after staking them");
        assertEq(post2.marketEngineVaultBal, pre1.stakerVaultBal, "MarketEngine received stakers vault shares");
        assertEq(post2.totalShares, pre1.stakerVaultBal, "Staking totalShares == staked vault balance");

        // @audit seems wrong as there is weth rewards to distribute now, but refresh didn't occur
        assertEq(post2.valuePerShare, 0, "Staking valuePerShare 0 as no value distributed");

        // save snapshot of current state prior to unstake
        uint256 snapshotId = vm.snapshot();

        console.log("*** before first unstake ***");
        changePrank({ msgSender: user });
        marketMakingEngine.unstake(vaultId, post1.stakerShares);

        // the unstaker has not received any rewards and all the fees still in the market
        // @audit seems wrong as the user was staked prior to fees being received, so when they
        // unstaked they should have gotten paid
        assertEq(IERC20(fuzzVaultConfig.asset).balanceOf(address(marketMakingEngine)), marketFees);
        assertEq(IERC20(fuzzVaultConfig.asset).balanceOf(user), 0);

        // revert state back to the snapshot before the unstake
        vm.revertTo(snapshotId);

        // try another action to see if rewards will refresh;
        // a second user performs a deposit prior to first user unstake
        address user2 = users.sasuke.account;
        fundUserAndDepositInVault(user2, vaultId, assetsToDeposit);

        // first user then unstakes
        console.log("*** before second unstake ***");
        changePrank({ msgSender: user });
        marketMakingEngine.unstake(vaultId, post1.stakerShares);

        // @audit seems wrong - they still didn't get paid???
        // creditDelegation.updateVaultLastDistributedValues was never called
        assertEq(IERC20(fuzzVaultConfig.asset).balanceOf(user), 0);
    }
}
