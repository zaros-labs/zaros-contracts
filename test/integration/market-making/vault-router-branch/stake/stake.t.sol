// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";

// Zaros dependencies source
import { VaultRouterBranch } from "@zaros/market-making/branches/VaultRouterBranch.sol";

// Open Zeppelin dependencies
import { IERC20 } from "@openzeppelin/token/ERC20/IERC20.sol";

contract MarketMaking_stake_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        createVault();
        changePrank({ msgSender: users.naruto.account });
    }

    function test_RevertWhen_VaultIsInvalid() external {
        uint256 sharesToStake = 1e18;
        address indexToken = marketMakingEngine.workaround_Vault_getIndexToken(VAULT_ID);
        deal(address(indexToken), users.naruto.account, sharesToStake);

        IERC20(indexToken).approve(address(marketMakingEngine), sharesToStake);

        // it should revert
        vm.expectRevert();
        marketMakingEngine.stake(0, sharesToStake, "", false);
    }

    function test_WhenUserHasShares() external {
        uint256 sharesToStake = 1e18;
        address indexToken = marketMakingEngine.workaround_Vault_getIndexToken(VAULT_ID);
        deal(address(indexToken), users.naruto.account, sharesToStake);

        IERC20(indexToken).approve(address(marketMakingEngine), sharesToStake);

        vm.expectEmit();
        emit VaultRouterBranch.LogStake(VAULT_ID, users.naruto.account, sharesToStake);
        marketMakingEngine.stake(VAULT_ID, sharesToStake, "", false);

        bytes32 actorId = bytes32(uint256(uint160(address(users.naruto.account))));
        uint256 userStakedShares = marketMakingEngine.workaround_Vault_getActorStakedShares(VAULT_ID, actorId);

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
        whenTheUserHasAReferralCode
        whenTheReferralCodeIsNotCustom
    {
        // it should revert
    }

    function test_WhenTheReferralCodeIsNotEqualToMsgSender()
        external
        whenTheUserHasAReferralCode
        whenTheReferralCodeIsNotCustom
    {
        // it should emit {LogReferralSet} event
    }
}
