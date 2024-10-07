// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { FeeDistributionBranch } from "@zaros/market-making/branches/FeeDistributionBranch.sol";

// PRB Math dependencies
import { ud60x18 } from "@prb-math/UD60x18.sol";
import { sd59x18 } from "@prb-math/SD59x18.sol";

import { IERC20 } from "@openzeppelin/token/ERC20/IERC20.sol";

contract claimFees_Integration_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        createVaults(marketMakingEngine, INITIAL_VAULT_ID, FINAL_VAULT_ID);
        changePrank({ msgSender: users.naruto.account });
    }

    function test_RevertWhen_VaultDoesNotExist() external {
        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.VaultDoesNotExist.selector));
        marketMakingEngine.claimFees(INVALID_VAULT_ID);
    }

    modifier whenVaultDoesExist() {
        _;
    }

    function test_GivenTheUserHasAlreadyClaimed(uint256 amountToReceive) external whenVaultDoesExist {
        uint256 maxDeposit = 10_000e18;
        amountToReceive = bound({ x: amountToReceive, min: WETH_MIN_DEPOSIT_MARGIN, max: maxDeposit });

        changePrank({ msgSender: address(perpsEngine) });

        // Set the market ID and WETH address
        setMarketDebtId(INITIAL_MARKET_DEBT_ID);
        marketMakingEngine.workaround_setWethAddress(address(wEth));

        marketMakingEngine.workaround_Collateral_setParams(
            address(wEth),
            WETH_CORE_VAULT_CREDIT_RATIO,
            WETH_CORE_VAULT_IS_ENABLED,
            WETH_DECIMALS,
            address(0)
        );

        // set perpsEngine address in MarketMakingEngineConfiguration
        marketMakingEngine.workaround_setPerpsEngineAddress(address(perpsEngine));

        // set contract with initial weth fees
        receiveOrderFeeInFeeDistribution(address(wEth), amountToReceive);

        bytes32 actorId = bytes32(uint256(uint160(address(users.naruto.account))));
        uint256 actorShares = 100;

        // set actor shares
        marketMakingEngine.exposed_setActorShares(
            FINAL_VAULT_ID,
            actorId,
            ud60x18(actorShares)
        );

        // set total vault shares
        marketMakingEngine.workaround_Vault_setTotalStakedShares(FINAL_VAULT_ID, 1000);
        changePrank({ msgSender: users.naruto.account });

        // distribute fees to vault
        marketMakingEngine.exposed_distributeValue(FINAL_VAULT_ID, sd59x18(int256(amountToReceive)));

        // it should send user the claimable amount
        marketMakingEngine.claimFees(FINAL_VAULT_ID);

        // it should return revert
        vm.expectRevert(abi.encodeWithSelector(Errors.NoFeesToClaim.selector));
        marketMakingEngine.claimFees(FINAL_VAULT_ID);
    }

    function test_GivenTheUserHasZeroShares() external whenVaultDoesExist {
        uint256 actorShares = 0;

        bytes32 actorId = bytes32(uint256(uint160(address(users.naruto.account))));

        changePrank({ msgSender: address(perpsEngine) });
        // set Actor Shares
        marketMakingEngine.exposed_setActorShares(
            FINAL_VAULT_ID,
            actorId,
            ud60x18(actorShares)
        );
        // Set the market ID and WETH address
        setMarketDebtId(INITIAL_MARKET_DEBT_ID);
        marketMakingEngine.workaround_setWethAddress(address(wEth));

        marketMakingEngine.workaround_Collateral_setParams(
            address(wEth),
            WETH_CORE_VAULT_CREDIT_RATIO,
            WETH_CORE_VAULT_IS_ENABLED,
            WETH_DECIMALS,
            address(0)
        );

        int256 distributedAmount = 200e18;
        // set perpsEngine address in MarketMakingEngineConfiguration
        marketMakingEngine.workaround_setPerpsEngineAddress(address(perpsEngine));

        // set contract with initial weth fees
        receiveOrderFeeInFeeDistribution(address(wEth), uint256(distributedAmount));


        // set total vault shares
        marketMakingEngine.workaround_Vault_setTotalStakedShares(FINAL_VAULT_ID, 1000);
        changePrank({ msgSender: users.naruto.account });

        // distribute fees to vault
        marketMakingEngine.exposed_distributeValue(FINAL_VAULT_ID, sd59x18(distributedAmount));

        // accumulate actor fees
        marketMakingEngine.exposed_accumulateActor(FINAL_VAULT_ID, actorId);

        // it should return revert
        vm.expectRevert(abi.encodeWithSelector(Errors.NoSharesAvailable.selector));
        marketMakingEngine.claimFees(FINAL_VAULT_ID);
    }

    function testFuzz_GivenTheUserHasFeesToClaim(uint256 amountToReceive) external whenVaultDoesExist {
        uint256 maxDeposit = 10_000e18;
        amountToReceive = bound({ x: amountToReceive, min: WETH_MIN_DEPOSIT_MARGIN, max: maxDeposit });

        changePrank({ msgSender: address(perpsEngine) });

        // Set the market ID and WETH address
        setMarketDebtId(INITIAL_MARKET_DEBT_ID);
        marketMakingEngine.workaround_setWethAddress(address(wEth));

        marketMakingEngine.workaround_Collateral_setParams(
            address(wEth),
            WETH_CORE_VAULT_CREDIT_RATIO,
            WETH_CORE_VAULT_IS_ENABLED,
            WETH_DECIMALS,
            address(0)
        );

        // set perpsEngine address in MarketMakingEngineConfiguration
        marketMakingEngine.workaround_setPerpsEngineAddress(address(perpsEngine));

        // set contract with initial weth fees
        receiveOrderFeeInFeeDistribution(address(wEth), amountToReceive);

        bytes32 actorId = bytes32(uint256(uint160(address(users.naruto.account))));
        uint256 actorShares = 100;

        // set actor shares
        marketMakingEngine.exposed_setActorShares(
            FINAL_VAULT_ID,
            actorId,
            ud60x18(actorShares)
        );

        // set total vault shares
        marketMakingEngine.workaround_Vault_setTotalStakedShares(FINAL_VAULT_ID, 1000);
        changePrank({ msgSender: users.naruto.account });

        // distribute fees to vault
        marketMakingEngine.exposed_distributeValue(FINAL_VAULT_ID, sd59x18(int256(amountToReceive)));

        // Expect event emitted for claimed fees
        vm.expectEmit();
        emit FeeDistributionBranch.LogClaimFees(address(users.naruto.account), FINAL_VAULT_ID, amountToReceive/ 10);

        // it should send user the claimable amount
        marketMakingEngine.claimFees(FINAL_VAULT_ID);
        assertEq(IERC20(address(wEth)).balanceOf(address(users.naruto.account)), amountToReceive/ 10);
    }
}
