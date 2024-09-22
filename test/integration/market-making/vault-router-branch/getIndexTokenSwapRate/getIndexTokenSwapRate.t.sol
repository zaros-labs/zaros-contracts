// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";

// Open Zeppelin dependencies
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";
import { ERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";
import { IERC4626 } from "@openzeppelin/interfaces/IERC4626.sol";

contract GetIndexTokenSwapRate_Integration_Test is Base_Test {
    using SafeCast for uint256;

    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        createVaults(marketMakingEngine, INITIAL_VAULT_ID, FINAL_VAULT_ID);
        changePrank({ msgSender: users.naruto.account });
    }

    function testFuzz_WhenGetIndexTokenSwapRateIsCalled(uint128 vaultId) external {
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);
        vaultId = fuzzVaultConfig.vaultId;

        address vaultAsset = marketMakingEngine.workaround_Vault_getVaultAsset(vaultId);
        uint256 assetsToDeposit = 10 ** ERC20(vaultAsset).decimals();

        depositInVault(vaultId, assetsToDeposit.toUint128());
        int256 swapRate = marketMakingEngine.getIndexTokenSwapRate(vaultId);

        // it should return the swap rate
        assertAlmostEq(IERC4626(fuzzVaultConfig.indexToken).previewRedeem(assetsToDeposit).toInt256(), swapRate, 1e17);
    }
}
