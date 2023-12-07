// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { Base_Integration_Shared_Test } from "test/integration/shared/BaseIntegration.t.sol";

contract GetAccountMarginCollateralBalance_Integration_Test is Base_Integration_Shared_Test {
    function setUp() public override {
        Base_Integration_Shared_Test.setUp();
    }

    function testFuzz_GetAccountMarginCollateral(uint256 amountToDeposit) external {
        amountToDeposit = bound({ x: amountToDeposit, min: 1, max: USDZ_DEPOSIT_CAP });
        deal({ token: address(usdToken), to: users.naruto, give: amountToDeposit });

        uint128 perpsAccountId = createAccountAndDeposit(amountToDeposit, address(usdToken));

        uint256 marginCollateralAmount = perpsEngine.getAccountMarginCollateralBalance({
            accountId: perpsAccountId,
            collateralType: address(usdToken)
        }).intoUint256();
        assertEq(marginCollateralAmount, amountToDeposit, "getAccountMarginCollateral");
    }
}
