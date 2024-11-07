// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies test
import { Base_Test } from "test/Base.t.sol";
import { UsdTokenSwapKeeper } from "@zaros/external/chainlink/keepers/usd-token-swap-keeper/UsdTokenSwapKeeper.sol";
import { StabilityBranch } from "@zaros/market-making/branches/StabilityBranch.sol";
import { UsdTokenSwap } from "@zaros/market-making/leaves/UsdTokenSwap.sol";

// Open Zeppelin dependencies
import { IERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";

// PRB Math dependencies
import { ud60x18 } from "@prb-math/UD60x18.sol";

contract UsdTokenSwapKeeper_PerformUpkeep_Integration_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        createVaults(marketMakingEngine, INITIAL_VAULT_ID, FINAL_VAULT_ID);
        marketMakingEngine.configureEngine(address(marketMakingEngine), address(usdToken), true);
        changePrank({ msgSender: users.naruto.account });
    }

    modifier givenInitializeContract() {
        _;
    }

    function testFuzz_GivenCallPerformUpkeepFunction(
        uint256 vaultId,
        uint256 assetsToDeposit
    )
        external
        givenInitializeContract
    {
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        assetsToDeposit = bound({ x: assetsToDeposit, min: 1e18, max: fuzzVaultConfig.depositCap });

        deal({ token: address(fuzzVaultConfig.asset), to: fuzzVaultConfig.indexToken, give: type(uint256).max });

        address usdTokenSwapKeeper = usdTokenSwapKeepers[fuzzVaultConfig.asset];

        changePrank({ msgSender: users.owner.account });

        UsdTokenSwapKeeper(usdTokenSwapKeeper).setForwarder(users.keepersForwarder.account);

        marketMakingEngine.configureSystemKeeper(usdTokenSwapKeeper, true);

        changePrank({ msgSender: users.naruto.account });

        uint256 mockPrice = 2000e18 / 1e10;

        uint256 amountInUsd = assetsToDeposit * mockPrice;

        deal({ token: address(usdToken), to: users.naruto.account, give: amountInUsd });

        IERC20(usdToken).approve(address(marketMakingEngine), amountInUsd);

        uint128 minAmountOut = 0;

        initiateUsdSwap(fuzzVaultConfig.vaultId, amountInUsd, minAmountOut);

        bytes memory mockSignedReport = getMockedSignedReport(fuzzVaultConfig.streamId, mockPrice);

        bytes memory performData = abi.encode(mockSignedReport, abi.encode(users.naruto.account, 1));

        uint128 requestId = 1;
        UsdTokenSwap.SwapRequest memory request = marketMakingEngine.getSwapRequest(users.naruto.account, requestId);

        uint256 amountOut = marketMakingEngine.getAmountOutCollateral(amountInUsd, ud60x18(mockPrice));
        uint256 amountOutAfterFee = marketMakingEngine.deductFeeCollateral(amountOut, fuzzVaultConfig.asset, ud60x18(mockPrice));

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
            amountOutAfterFee
        );

        changePrank({ msgSender: users.keepersForwarder.account });
        UsdTokenSwapKeeper(usdTokenSwapKeeper).performUpkeep(performData);
    }
}
