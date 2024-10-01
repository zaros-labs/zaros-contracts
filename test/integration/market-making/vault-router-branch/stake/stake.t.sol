// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";

// Zaros dependencies source
import { VaultRouterBranch } from "@zaros/market-making/branches/VaultRouterBranch.sol";

// Open Zeppelin dependencies
import { IERC20 } from "@openzeppelin/token/ERC20/IERC20.sol";

contract Stake_Integration_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        createVaults(marketMakingEngine, INITIAL_VAULT_ID, FINAL_VAULT_ID);
        changePrank({ msgSender: users.naruto.account });
    }

    function testFuzz_RevertWhen_VaultIsInvalid(uint128 sharesToStake) external {
        // it should revert
        vm.expectRevert();
        marketMakingEngine.stake(INVALID_VAULT_ID, sharesToStake, "", false);
    }

    modifier whenVaultIdIsValid() {
        _;
    }

    function testFuzz_WhenUserHasShares(uint256 vaultId, uint256 sharesToStake) external whenVaultIdIsValid {
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        sharesToStake = bound({ x: sharesToStake, min: 1, max: type(uint128).max });
        address indexToken = fuzzVaultConfig.indexToken;
        deal(address(indexToken), users.naruto.account, sharesToStake);

        IERC20(indexToken).approve(address(marketMakingEngine), sharesToStake);

        vm.expectEmit();
        emit VaultRouterBranch.LogStake(fuzzVaultConfig.vaultId, users.naruto.account, sharesToStake);
        marketMakingEngine.stake(fuzzVaultConfig.vaultId, uint128(sharesToStake), "", false);

        bytes32 actorId = bytes32(uint256(uint160(address(users.naruto.account))));
        uint256 userStakedShares = marketMakingEngine.workaround_Vault_getActorStakedShares(fuzzVaultConfig.vaultId, actorId);

        // it should update staked shares
        assertEq(sharesToStake, userStakedShares);
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
}
