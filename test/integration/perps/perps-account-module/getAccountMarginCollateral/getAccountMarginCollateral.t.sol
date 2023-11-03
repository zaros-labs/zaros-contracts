// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { Base_Integration_Shared_Test } from "test/integration/shared/BaseIntegration.t.sol";

contract GetAccountMarginCollateral_Integration_Test is Base_Integration_Shared_Test {
    function setUp() public override {
        Base_Integration_Shared_Test.setUp();
    }

    function testFuzz_GetAccountMarginCollateral(uint256 amountToDeposit) external {
        vm.assume({ condition: amountToDeposit > 0 });
        deal({ token: address(usdToken), to: users.naruto, give: amountToDeposit });

        uint256 perpsAccountId = _createAccountAndDeposit(amountToDeposit, address(usdToken));

        uint256 marginCollateral = perpsEngine.getAccountMarginCollateral({
            accountId: perpsAccountId,
            collateralType: address(usdToken)
        }).intoUint256();
        assertEq(marginCollateral, amountToDeposit, "getAccountMarginCollateral");
    }
}
