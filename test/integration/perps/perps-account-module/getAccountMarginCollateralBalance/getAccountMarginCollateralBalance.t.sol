// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Integration_Shared_Test } from "test/integration/shared/BaseIntegration.t.sol";

contract GetAccountMarginCollateralBalance_Integration_Test is Base_Integration_Shared_Test {
    function setUp() public override {
        Base_Integration_Shared_Test.setUp();
    }

    function testFuzz_GetAccountMarginCollateralBalance(uint256 amountToDeposit, uint256 marketId) external {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);
        FuzzMarginPortfolio memory fuzzMarginPortfolio = getFuzzMarginPortfolio(fuzzMarketConfig, 0, amountToDeposit);

        uint128 perpsAccountId = createAccountAndDeposit(fuzzMarginPortfolio.marginValueUsd, address(usdToken));

        uint256 marginCollateralAmount = perpsEngine.getAccountMarginCollateralBalance({
            accountId: perpsAccountId,
            collateralType: address(usdToken)
        }).intoUint256();
        assertEq(marginCollateralAmount, fuzzMarginPortfolio.marginValueUsd, "getAccountMarginCollateralBalance");
    }
}
