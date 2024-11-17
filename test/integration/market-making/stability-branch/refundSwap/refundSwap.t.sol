// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { StabilityBranch } from "@zaros/market-making/branches/StabilityBranch.sol";
import { UsdTokenSwap } from "@zaros/market-making/leaves/UsdTokenSwap.sol";

contract RefundSwap_Integration_Test is Base_Test {
// function setUp() public virtual override {
//     Base_Test.setUp();
//     changePrank({ msgSender: users.owner.account });
//     createVaults(marketMakingEngine, INITIAL_VAULT_ID, FINAL_VAULT_ID);
//     marketMakingEngine.configureEngine(address(marketMakingEngine), address(usdToken), true);
//     changePrank({ msgSender: users.naruto.account });
// }

// function testFuzz_RevertWhen_RequestIsAlreadyProcessed(uint256 vaultId, uint256 swapAmount) external {
//     VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

//     deal({ token: address(fuzzVaultConfig.asset), to: fuzzVaultConfig.indexToken, give: type(uint256).max });

//     swapAmount = bound({ x: swapAmount, min: 1e18, max: type(uint128).max });

//     deal({ token: address(usdToken), to: users.naruto.account, give: swapAmount });

//     uint128 minAmountOut = 0;

//     initiateUsdSwap(uint128(fuzzVaultConfig.vaultId), swapAmount, minAmountOut);

//     bytes memory priceData = getMockedSignedReport(fuzzVaultConfig.streamId, 1e10);
//     address usdTokenSwapKeeper = usdTokenSwapKeepers[fuzzVaultConfig.asset];

//     uint128 requestId = 1;
//     changePrank({ msgSender: usdTokenSwapKeeper });

//     marketMakingEngine.fulfillSwap(users.naruto.account, requestId, priceData, address(marketMakingEngine));

//     changePrank({ msgSender: users.naruto.account });

//     // it should revert
//     vm.expectRevert(
//         abi.encodeWithSelector(Errors.RequestAlreadyProcessed.selector, users.naruto.account, requestId)
//     );

//     marketMakingEngine.refundSwap(requestId, address(marketMakingEngine));
// }

// modifier whenRequestIsNotProcessed() {
//     _;
// }

// function testFuzz_RevertWhen_DeadlineHasNotPassed(
//     uint256 vaultId,
//     uint256 swapAmount
// )
//     external
//     whenRequestIsNotProcessed
// {
//     VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

//     deal({ token: address(fuzzVaultConfig.asset), to: fuzzVaultConfig.indexToken, give: type(uint256).max });

//     swapAmount = bound({ x: swapAmount, min: 1e18, max: type(uint128).max });

//     deal({ token: address(usdToken), to: users.naruto.account, give: swapAmount });

//     uint128 minAmountOut = 0;

//     changePrank({ msgSender: users.owner.account });
//     marketMakingEngine.configureUsdTokenSwap(0, 0, uint128(300));
//     changePrank({ msgSender: users.naruto.account });

//     initiateUsdSwap(uint128(fuzzVaultConfig.vaultId), uint128(swapAmount), minAmountOut);

//     uint128 requestId = 1;

//     // it should revert
//     vm.expectRevert(abi.encodeWithSelector(Errors.RequestNotExpired.selector, users.naruto.account, requestId));

//     marketMakingEngine.refundSwap(requestId, address(marketMakingEngine));
// }

// function testFuzz_WhenDeadlineHasPassed(uint256 vaultId, uint256 swapAmount) external whenRequestIsNotProcessed {
//     VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

//     deal({ token: address(fuzzVaultConfig.asset), to: fuzzVaultConfig.indexToken, give: type(uint256).max });

//     swapAmount = bound({ x: swapAmount, min: 1e18, max: type(uint128).max });

//     deal({ token: address(usdToken), to: users.naruto.account, give: swapAmount });

//     uint128 minAmountOut = 0;

//     initiateUsdSwap(uint128(fuzzVaultConfig.vaultId), uint128(swapAmount), minAmountOut);

//     uint128 requestId = 1;

//     skip(MAX_VERIFICATION_DELAY + 1);

//     (uint256 refundAmount,) = marketMakingEngine.deductFeeUsd(swapAmount);

//     UsdTokenSwap.SwapRequest memory request = marketMakingEngine.getSwapRequest(users.naruto.account, requestId);

//     // it should emit {LogRefundSwap} event
//     vm.expectEmit({ emitter: address(marketMakingEngine) });
//     emit StabilityBranch.LogRefundSwap(
//         users.naruto.account,
//         requestId,
//         request.vaultId,
//         request.amountIn,
//         request.minAmountOut,
//         request.assetOut,
//         request.deadline,
//         refundAmount
//     );

//     marketMakingEngine.refundSwap(requestId, address(marketMakingEngine));
//     // it should transfer usd back to user
// }
}
