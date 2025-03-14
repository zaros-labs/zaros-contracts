// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";

// Open Zeppelin dependencies
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";
import { IERC4626 } from "@openzeppelin/interfaces/IERC4626.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18 } from "@prb-math/SD59x18.sol";

contract GetVaultAssetSwapRate_Integration_Test is Base_Test {
    using SafeCast for uint256;

    function setUp() public virtual override {
        Base_Test.setUp();
    }

    function testFuzz_WhenGetVaultAssetSwapRateIsCalled(uint128 vaultId, uint256 amountToSwap) external {
        amountToSwap = bound({ x: amountToSwap, min: 0, max: uint256(type(int256).max) });
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);
        vaultId = fuzzVaultConfig.vaultId;

        UD60x18 swapRate = marketMakingEngine.getVaultAssetSwapRate(vaultId, amountToSwap, false);

        // it should return the swap rate
        assertAlmostEq(
            IERC4626(fuzzVaultConfig.indexToken).previewDeposit(amountToSwap), swapRate.intoUint256(), 1e17
        );
    }
}
