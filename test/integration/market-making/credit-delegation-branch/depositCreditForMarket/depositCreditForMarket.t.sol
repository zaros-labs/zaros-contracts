// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { CreditDelegationBranch } from "@zaros/market-making/branches/CreditDelegationBranch.sol";

// Open Zeppelin dependencies
import { IERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";

contract CreditDelegationBranch_DepositCreditForMarket_Integration_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        createVaults(marketMakingEngine, INITIAL_VAULT_ID, FINAL_VAULT_ID, true, address(perpsEngine));
        configureMarkets();
        changePrank({ msgSender: users.naruto.account });
    }

    function testFuzz_RevertGiven_TheSenderIsNotTheRegisteredEngine(
        uint256 marketId,
        uint256 amount,
        uint256 vaultId
    )
        external
    {
        amount = bound({ x: amount, min: 1, max: type(uint256).max });

        PerpMarketCreditConfig memory fuzzMarketConfig = getFuzzPerpMarketCreditConfig(marketId);
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.Unauthorized.selector, users.naruto.account) });

        marketMakingEngine.depositCreditForMarket(fuzzMarketConfig.marketId, fuzzVaultConfig.asset, amount);
    }

    modifier givenTheSenderIsTheRegisteredEngine() {
        _;
    }

    function testFuzz_RevertWhen_TheAmountIsZero(
        uint256 marketId,
        uint256 vaultId
    )
        external
        givenTheSenderIsTheRegisteredEngine
    {
        PerpMarketCreditConfig memory fuzzMarketConfig = getFuzzPerpMarketCreditConfig(marketId);
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        changePrank({ msgSender: address(perpsEngine) });

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "amount") });

        marketMakingEngine.depositCreditForMarket(fuzzMarketConfig.marketId, fuzzVaultConfig.asset, 0);
    }

    modifier whenTheAmountIsNotZero() {
        _;
    }

    function testFuzz_RevertWhen_TheCollateralIsNotEnabled(
        uint256 marketId,
        uint256 amount
    )
        external
        givenTheSenderIsTheRegisteredEngine
        whenTheAmountIsNotZero
    {
        amount = bound({ x: amount, min: 1, max: type(uint256).max });

        PerpMarketCreditConfig memory fuzzMarketConfig = getFuzzPerpMarketCreditConfig(marketId);
        address assetNotEnabled = address(123);

        changePrank({ msgSender: address(perpsEngine) });

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.CollateralDisabled.selector, address(0)) });

        marketMakingEngine.depositCreditForMarket(fuzzMarketConfig.marketId, assetNotEnabled, amount);
    }

    modifier whenTheCollateralIsEnabled() {
        _;
    }

    function testFuzz_RevertWhen_TheMarketIsNotLive(
        uint256 marketId,
        uint256 amount,
        uint256 vaultId
    )
        external
        givenTheSenderIsTheRegisteredEngine
        whenTheAmountIsNotZero
        whenTheCollateralIsEnabled
    {
        amount = bound({ x: amount, min: 1, max: type(uint256).max });

        uint128 invalidMarketId = 0;
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        changePrank({ msgSender: address(perpsEngine) });

        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.MarketDoesNotExist.selector, invalidMarketId));

        marketMakingEngine.depositCreditForMarket(invalidMarketId, fuzzVaultConfig.asset, amount);
    }

    modifier whenTheMarketIsLive() {
        _;
    }

    function testFuzz_RevertWhen_TheTotalDelegatedCreditUsdIsZero(
        uint256 marketId,
        uint256 amount,
        uint256 vaultId
    )
        external
        givenTheSenderIsTheRegisteredEngine
        whenTheAmountIsNotZero
        whenTheCollateralIsEnabled
        whenTheMarketIsLive
    {
        amount = bound({ x: amount, min: 1, max: type(uint256).max });

        PerpMarketCreditConfig memory fuzzMarketConfig = getFuzzPerpMarketCreditConfig(marketId);
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        marketMakingEngine.workaround_updateMarketTotalDelegatedCreditUsd(fuzzMarketConfig.marketId, 0);

        deal({ token: address(wEth), to: address(perpsEngine), give: amount });
        changePrank({ msgSender: address(perpsEngine) });

        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.NoDelegatedCredit.selector, fuzzMarketConfig.marketId));

        marketMakingEngine.depositCreditForMarket(fuzzMarketConfig.marketId, fuzzVaultConfig.asset, amount);
    }

    function testFuzz_WhenTheTotalDelegatedCreditUsdIsGreaterThanZero(
        uint256 marketId,
        uint256 amount,
        uint256 vaultId
    )
        external
        givenTheSenderIsTheRegisteredEngine
        whenTheAmountIsNotZero
        whenTheCollateralIsEnabled
        whenTheMarketIsLive
    {
        amount = bound({ x: amount, min: 1, max: type(uint128).max });

        PerpMarketCreditConfig memory fuzzMarketConfig = getFuzzPerpMarketCreditConfig(marketId);
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        deal({ token: address(fuzzVaultConfig.asset), to: address(perpsEngine), give: amount });
        changePrank({ msgSender: address(perpsEngine) });

        // it should emit {LogDepositCreditForMarket} event
        vm.expectEmit();
        emit CreditDelegationBranch.LogDepositCreditForMarket(
            address(perpsEngine), fuzzMarketConfig.marketId, fuzzVaultConfig.asset, amount
        );

        marketMakingEngine.depositCreditForMarket(fuzzMarketConfig.marketId, fuzzVaultConfig.asset, amount);

        uint256 mmBalance = IERC20(fuzzVaultConfig.asset).balanceOf(address(marketMakingEngine));

        // it should deposit credit for market
        assertEq(mmBalance, amount);
    }
}
