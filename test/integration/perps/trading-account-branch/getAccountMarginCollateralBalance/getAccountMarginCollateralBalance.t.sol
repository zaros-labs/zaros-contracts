// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Integration_Shared_Test } from "test/integration/shared/BaseIntegration.t.sol";

contract GetAccountMarginCollateralBalance_Integration_Test is Base_Integration_Shared_Test {
    function setUp() public override {
        Base_Integration_Shared_Test.setUp();
    }

    function testFuzz_GetAccountMarginCollateralBalance(uint256 amountToDeposit) external {
        amountToDeposit = bound({ x: amountToDeposit, min: 1, max: USDZ_DEPOSIT_CAP });
        deal({ token: address(usdToken), to: users.naruto, give: amountToDeposit });

        uint128 tradingAccountId = createAccountAndDeposit(amountToDeposit, address(usdToken));

        uint256 marginCollateralAmount = perpsEngine.getAccountMarginCollateralBalance({
            tradingAccountId: tradingAccountId,
            collateralType: address(usdToken)
        }).intoUint256();
        assertEq(marginCollateralAmount, amountToDeposit, "getAccountMarginCollateralBalance");
    }
}
