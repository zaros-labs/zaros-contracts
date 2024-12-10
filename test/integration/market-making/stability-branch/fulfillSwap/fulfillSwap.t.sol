// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies test
import { Base_Test } from "test/Base.t.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { StabilityBranch } from "@zaros/market-making/branches/StabilityBranch.sol";
import { UsdTokenSwapConfig } from "@zaros/market-making/leaves/UsdTokenSwapConfig.sol";

// Open Zeppelin dependencies
import { IERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";

// PRB Math dependencies
import { ud60x18, UD60x18 } from "@prb-math/UD60x18.sol";

contract FulfillSwap_Integration_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        createVaults(marketMakingEngine, INITIAL_VAULT_ID, FINAL_VAULT_ID);
        marketMakingEngine.configureEngine(address(marketMakingEngine), address(usdToken), true);
        changePrank({ msgSender: users.naruto.account });
    }

    function test_RevertWhen_CallerIsNotKeeper() external {
        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.Unauthorized.selector, users.naruto.account));

        marketMakingEngine.fulfillSwap(users.naruto.account, 1, new bytes(0), address(marketMakingEngine));
    }

    modifier whenCallerIsKeeper() {
        _;
    }

    function testFuzz_RevertWhen_RequestWasAlreadyProcessed(
        uint256 vaultId,
        uint256 swapAmount
    )
        external
        whenCallerIsKeeper
    {
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        deal({ token: address(fuzzVaultConfig.asset), to: fuzzVaultConfig.indexToken, give: type(uint256).max });

        swapAmount = bound({ x: swapAmount, min: 1e18, max: type(uint128).max });

        deal({ token: address(usdToken), to: users.naruto.account, give: swapAmount });

        uint128 minAmountOut = 0;

        initiateUsdSwap(uint128(fuzzVaultConfig.vaultId), swapAmount, minAmountOut);

        bytes memory priceData = getMockedSignedReport(fuzzVaultConfig.streamId, 1e10);
        address usdTokenSwapKeeper = usdTokenSwapKeepers[fuzzVaultConfig.asset];

        uint128 requestId = 1;
        changePrank({ msgSender: usdTokenSwapKeeper });
        marketMakingEngine.fulfillSwap(users.naruto.account, requestId, priceData, address(marketMakingEngine));

        // it should revert
        vm.expectRevert(
            abi.encodeWithSelector(Errors.RequestAlreadyProcessed.selector, users.naruto.account, requestId)
        );
        marketMakingEngine.fulfillSwap(users.naruto.account, requestId, priceData, address(marketMakingEngine));
    }

    modifier whenRequestWasNotYetProcessed() {
        _;
    }

    function testFuzz_RevertWhen_SwapRequestHasExpired(
        uint256 vaultId,
        uint256 swapAmount
    )
        external
        whenCallerIsKeeper
        whenRequestWasNotYetProcessed
    {
        uint128 maxExecutionEndTime = 100;
        changePrank({ msgSender: users.owner.account });
        marketMakingEngine.configureUsdTokenSwapConfig(1, 30, maxExecutionEndTime);
        changePrank({ msgSender: users.naruto.account });

        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        deal({ token: address(fuzzVaultConfig.asset), to: fuzzVaultConfig.indexToken, give: type(uint256).max });

        swapAmount = bound({ x: swapAmount, min: 1e18, max: type(uint96).max });

        deal({ token: address(usdToken), to: users.naruto.account, give: swapAmount });

        uint128 minAmountOut = 0;

        initiateUsdSwap(uint128(fuzzVaultConfig.vaultId), swapAmount, minAmountOut);

        bytes memory priceData = getMockedSignedReport(fuzzVaultConfig.streamId, 1e10);
        address usdTokenSwapKeeper = usdTokenSwapKeepers[fuzzVaultConfig.asset];

        UsdTokenSwapConfig.SwapRequest memory request = marketMakingEngine.getSwapRequest(users.naruto.account, 1);

        // Fast forward time so request expires
        skip(maxExecutionEndTime + 1);

        uint128 requestId = 1;
        changePrank({ msgSender: usdTokenSwapKeeper });

        // it should revert
        vm.expectRevert(
            abi.encodeWithSelector(Errors.SwapRequestExpired.selector, users.naruto.account, 1, request.deadline)
        );

        marketMakingEngine.fulfillSwap(users.naruto.account, requestId, priceData, address(marketMakingEngine));
    }

    modifier whenSwapRequestNotExpired() {
        _;
    }

    function testFuzz_RevertWhen_SlippageCheckFails(
        uint256 vaultId,
        uint256 swapAmount
    )
        external
        whenCallerIsKeeper
        whenRequestWasNotYetProcessed
        whenSwapRequestNotExpired
    {
        changePrank({ msgSender: users.owner.account });
        uint128 bpsFee = 30;
        marketMakingEngine.configureUsdTokenSwapConfig(1, bpsFee, type(uint96).max);
        changePrank({ msgSender: users.naruto.account });

        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        deal({ token: address(fuzzVaultConfig.asset), to: fuzzVaultConfig.indexToken, give: type(uint256).max });

        swapAmount = bound({ x: swapAmount, min: 1e18, max: type(uint80).max });

        deal({ token: address(usdToken), to: users.naruto.account, give: swapAmount });

        uint128 minAmountOut = type(uint128).max;

        initiateUsdSwap(uint128(fuzzVaultConfig.vaultId), swapAmount, minAmountOut);

        uint256 price = 1e10;
        bytes memory priceData = getMockedSignedReport(fuzzVaultConfig.streamId, price);
        address usdTokenSwapKeeper = usdTokenSwapKeepers[fuzzVaultConfig.asset];

        uint128 requestId = 1;
        changePrank({ msgSender: usdTokenSwapKeeper });

        UD60x18 amountOut =
<<<<<<< HEAD
            marketMakingEngine.getAmountOfAssetOut(fuzzVaultConfig.vaultId, ud60x18(swapAmount), ud60x18(price));
=======
            marketMakingEngine.getAmountOfAssetOut(uint128(vaultId), ud60x18(swapAmount), ud60x18(price));
>>>>>>> 4148cbc1 (test: update calls to getAmountOfAssetOut)

        (UD60x18 baseFeeX18, UD60x18 swapFeeX18) =
            marketMakingEngine.getFeesForAssetsAmountOut(amountOut, ud60x18(price));

        uint256 amountOutAfterFee =
            convertUd60x18ToTokenAmount(fuzzVaultConfig.asset, amountOut.sub(baseFeeX18.add(swapFeeX18)));

        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.SlippageCheckFailed.selector, minAmountOut, amountOutAfterFee));

        marketMakingEngine.fulfillSwap(users.naruto.account, requestId, priceData, address(marketMakingEngine));
    }

    function testFuzz_WhenSlippageCheckPasses(
        uint256 vaultId,
        uint256 swapAmount
    )
        external
        whenCallerIsKeeper
        whenRequestWasNotYetProcessed
        whenSwapRequestNotExpired
    {
        changePrank({ msgSender: users.owner.account });
        marketMakingEngine.configureUsdTokenSwapConfig(1, 30, type(uint96).max);
        changePrank({ msgSender: users.naruto.account });

        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        deal({ token: address(fuzzVaultConfig.asset), to: fuzzVaultConfig.indexToken, give: type(uint256).max });

        swapAmount = bound({ x: swapAmount, min: 1e18, max: type(uint96).max });

        deal({ token: address(usdToken), to: users.naruto.account, give: swapAmount });

        uint128 minAmountOut = 0;

        initiateUsdSwap(uint128(fuzzVaultConfig.vaultId), swapAmount, minAmountOut);

        bytes memory priceData = getMockedSignedReport(fuzzVaultConfig.streamId, 1e10);
        address usdTokenSwapKeeper = usdTokenSwapKeepers[fuzzVaultConfig.asset];

        uint128 requestId = 1;
        UsdTokenSwapConfig.SwapRequest memory request =
            marketMakingEngine.getSwapRequest(users.naruto.account, requestId);

        UD60x18 amountOut =
<<<<<<< HEAD
            marketMakingEngine.getAmountOfAssetOut(fuzzVaultConfig.vaultId, ud60x18(swapAmount), ud60x18(1e10));
=======
            marketMakingEngine.getAmountOfAssetOut(uint128(vaultId), ud60x18(swapAmount), ud60x18(1e10));
>>>>>>> 4148cbc1 (test: update calls to getAmountOfAssetOut)

        (UD60x18 baseFeeX18, UD60x18 swapFeeX18) =
            marketMakingEngine.getFeesForAssetsAmountOut(amountOut, ud60x18(1e10));

        uint256 amountOutAfterFee =
            convertUd60x18ToTokenAmount(fuzzVaultConfig.asset, amountOut.sub(baseFeeX18.add(swapFeeX18)));

        changePrank({ msgSender: usdTokenSwapKeeper });

        UD60x18 protocolSwapFee = swapFeeX18.mul(ud60x18(marketMakingEngine.exposed_getTotalFeeRecipientsShares()));
        uint256 protocolReward = convertUd60x18ToTokenAmount(fuzzVaultConfig.asset, baseFeeX18.add(protocolSwapFee));

        // it should emit {LogFulfillSwap} event
        vm.expectEmit({ emitter: address(marketMakingEngine) });
        emit StabilityBranch.LogFulfillSwap(
            users.naruto.account,
            requestId,
            fuzzVaultConfig.vaultId,
            request.amountIn,
            request.minAmountOut,
            request.assetOut,
            request.deadline,
            amountOutAfterFee,
            baseFeeX18.intoUint256(),
            swapFeeX18.intoUint256(),
            protocolReward
        );

        marketMakingEngine.fulfillSwap(users.naruto.account, requestId, priceData, address(marketMakingEngine));

        // it should transfer assets to user
        assertGt(IERC20(fuzzVaultConfig.asset).balanceOf(users.naruto.account), 0, "balance of user > 0 failed");

        // it should burn USD token from contract
        assertEq(IERC20(usdToken).balanceOf(fuzzVaultConfig.indexToken), 0, "balance of zlp vault == 0 failed");
    }
}
