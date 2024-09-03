// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";

contract MarketMaking_getIndexTokenSwapRate_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        createVault();
        changePrank({ msgSender: users.naruto.account });
    }

    function test_WhenGetIndexTokenSwapRateIsCalled() external {
        uint128 assetsToDeposit = 1e18;
        depositInVault(assetsToDeposit);
        uint256 swapRate = marketMakingEngine.getIndexTokenSwapRate(VAULT_ID);

        // it should return the swap rate
        assertAlmostEq(zlpVault.previewRedeem(assetsToDeposit), swapRate, 1e17);
    }
}
