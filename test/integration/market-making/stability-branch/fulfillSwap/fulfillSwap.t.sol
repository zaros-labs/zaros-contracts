// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies test
import { Base_Test } from "test/Base.t.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { StabilityBranch } from "@zaros/market-making/branches/StabilityBranch.sol";
import { UsdTokenSwap } from "@zaros/market-making/leaves/UsdTokenSwap.sol";

// Open Zeppelin dependencies
import { IERC20, ERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";

// PRB Math dependencies
import { ud60x18 } from "@prb-math/UD60x18.sol";

contract FulfillSwap_Integration_Test is Base_Test {
// function setUp() public virtual override {
//     Base_Test.setUp();
//     changePrank({ msgSender: users.owner.account });
//     createVaults(marketMakingEngine, INITIAL_VAULT_ID, FINAL_VAULT_ID);
//     marketMakingEngine.configureEngine(address(marketMakingEngine), address(usdToken), true);
//     changePrank({ msgSender: users.naruto.account });
// }

// function test_RevertWhen_CallerIsNotKeeper() external {
//     // it should revert
//     vm.expectRevert(abi.encodeWithSelector(Errors.Unauthorized.selector, users.naruto.account));

//     marketMakingEngine.fulfillSwap(users.naruto.account, 1, new bytes(0), address(marketMakingEngine));
// }

// modifier whenCallerIsKeeper() {
//     _;
// }

// function testFuzz_RevertWhen_RequestWasAlreadyProcessed(
//     uint256 vaultId,
//     uint256 swapAmount
// )
//     external
//     whenCallerIsKeeper
// {
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

//     // it should revert
//     vm.expectRevert(
//         abi.encodeWithSelector(Errors.RequestAlreadyProcessed.selector, users.naruto.account, requestId)
//     );
//     marketMakingEngine.fulfillSwap(users.naruto.account, requestId, priceData, address(marketMakingEngine));
// }

// modifier whenRequestWasNotYetProcessed() {
//     _;
// }

// function testFuzz_RevertWhen_SwapRequestHasExpired(
//     uint256 vaultId,
//     uint256 swapAmount
// )
//     external
//     whenCallerIsKeeper
//     whenRequestWasNotYetProcessed
// {
//     uint128 maxExecutionEndTime = 100;
//     changePrank({ msgSender: users.owner.account });
//     marketMakingEngine.configureUsdTokenSwap(1, 30, maxExecutionEndTime);
//     changePrank({ msgSender: users.naruto.account });

//     VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

//     deal({ token: address(fuzzVaultConfig.asset), to: fuzzVaultConfig.indexToken, give: type(uint256).max });

//     swapAmount = bound({ x: swapAmount, min: 1e18, max: type(uint96).max });

//     deal({ token: address(usdToken), to: users.naruto.account, give: swapAmount });

//     uint128 minAmountOut = 0;

//     initiateUsdSwap(uint128(fuzzVaultConfig.vaultId), swapAmount, minAmountOut);

//     bytes memory priceData = getMockedSignedReport(fuzzVaultConfig.streamId, 1e10);
//     address usdTokenSwapKeeper = usdTokenSwapKeepers[fuzzVaultConfig.asset];

//     UsdTokenSwap.SwapRequest memory request = marketMakingEngine.getSwapRequest(users.naruto.account, 1);

//     // Fast forward time so request expires
//     skip(maxExecutionEndTime + 1);

//     uint128 requestId = 1;
//     changePrank({ msgSender: usdTokenSwapKeeper });

//     // it should revert
//     vm.expectRevert(
//         abi.encodeWithSelector(Errors.SwapRequestExpired.selector, users.naruto.account, 1, request.deadline)
//     );

//     marketMakingEngine.fulfillSwap(users.naruto.account, requestId, priceData, address(marketMakingEngine));
// }

// modifier whenSwapRequestNotExpired() {
//     _;
// }

// function testFuzz_RevertWhen_SlippageCheckFails(
//     uint256 vaultId,
//     uint256 swapAmount
// )
//     external
//     whenCallerIsKeeper
//     whenRequestWasNotYetProcessed
//     whenSwapRequestNotExpired
// {
//     changePrank({ msgSender: users.owner.account });
//     uint128 bpsFee = 30;
//     marketMakingEngine.configureUsdTokenSwap(1, bpsFee, type(uint96).max);
//     changePrank({ msgSender: users.naruto.account });

//     VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

//     deal({ token: address(fuzzVaultConfig.asset), to: fuzzVaultConfig.indexToken, give: type(uint256).max });

//     swapAmount = bound({ x: swapAmount, min: 1e18, max: type(uint80).max });

//     deal({ token: address(usdToken), to: users.naruto.account, give: swapAmount });

//     uint128 minAmountOut = type(uint128).max;

//     initiateUsdSwap(uint128(fuzzVaultConfig.vaultId), swapAmount, minAmountOut);

//     uint256 price = 1e10;
//     bytes memory priceData = getMockedSignedReport(fuzzVaultConfig.streamId, price);
//     address usdTokenSwapKeeper = usdTokenSwapKeepers[fuzzVaultConfig.asset];

//     uint128 requestId = 1;
//     changePrank({ msgSender: usdTokenSwapKeeper });

//     uint256 amountOut = swapAmount * price / 100;

//     uint8 decimals = ERC20(fuzzVaultConfig.asset).decimals();
//     uint256 amountOutAfterFee = amountOut - (10 ** decimals) / price - (amountOut * bpsFee / 10_000);

//     // it should revert
//     vm.expectRevert(abi.encodeWithSelector(Errors.SlippageCheckFailed.selector, minAmountOut, amountOutAfterFee));

//     marketMakingEngine.fulfillSwap(users.naruto.account, requestId, priceData, address(marketMakingEngine));
// }

// function testFuzz_WhenSlippageCheckPasses(
//     uint256 vaultId,
//     uint256 swapAmount
// )
//     external
//     whenCallerIsKeeper
//     whenRequestWasNotYetProcessed
//     whenSwapRequestNotExpired
// {
//     changePrank({ msgSender: users.owner.account });
//     marketMakingEngine.configureUsdTokenSwap(1, 30, type(uint96).max);
//     changePrank({ msgSender: users.naruto.account });

//     VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

//     deal({ token: address(fuzzVaultConfig.asset), to: fuzzVaultConfig.indexToken, give: type(uint256).max });

//     swapAmount = bound({ x: swapAmount, min: 1e18, max: type(uint96).max });

//     deal({ token: address(usdToken), to: users.naruto.account, give: swapAmount });

//     uint128 minAmountOut = 0;

//     initiateUsdSwap(uint128(fuzzVaultConfig.vaultId), swapAmount, minAmountOut);

//     bytes memory priceData = getMockedSignedReport(fuzzVaultConfig.streamId, 1e10);
//     address usdTokenSwapKeeper = usdTokenSwapKeepers[fuzzVaultConfig.asset];

//     uint128 requestId = 1;
//     UsdTokenSwap.SwapRequest memory request = marketMakingEngine.getSwapRequest(users.naruto.account, requestId);

//     uint256 amountOut = marketMakingEngine.getAmountOfAssetOut(swapAmount, ud60x18(1e10));
//     uint256 amountOutAfterFee =
//         marketMakingEngine.deductFeeCollateral(amountOut, fuzzVaultConfig.asset, ud60x18(1e10));

//     changePrank({ msgSender: usdTokenSwapKeeper });

//     // it should emit {LogFulfillSwap} event
//     vm.expectEmit({ emitter: address(marketMakingEngine) });
//     emit StabilityBranch.LogFulfillSwap(
//         users.naruto.account,
//         requestId,
//         fuzzVaultConfig.vaultId,
//         request.amountIn,
//         request.minAmountOut,
//         request.assetOut,
//         request.deadline,
//         amountOutAfterFee
//     );

//     marketMakingEngine.fulfillSwap(users.naruto.account, requestId, priceData, address(marketMakingEngine));

//     // it should transfer assets to user
//     assertGt(IERC20(fuzzVaultConfig.asset).balanceOf(users.naruto.account), 0, "balance of user > 0 failed");

//     // it should burn USD token from contract
//     assertEq(IERC20(usdToken).balanceOf(fuzzVaultConfig.indexToken), 0, "balance of zlp vault == 0 failed");
// }
}
