// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { Base_Integration_Shared_Test } from "test/integration/shared/BaseIntegration.t.sol";

contract GetAccountMarginCollateral_Integration_Concrete_Test is Base_Integration_Shared_Test {
    function setUp() public override {
        Base_Integration_Shared_Test.setUp();
    }

    function test_GetAccountMarginCollateral() external {
        uint256 amount = 100e18;
        uint256 perpsAccountId = _createAccountAndDeposit(amount, address(usdToken));

        uint256 marginCollateral = perpsEngine.getAccountMarginCollateral({
            accountId: perpsAccountId,
            collateralType: address(usdToken)
        }).intoUint256();
        assertEq(marginCollateral, amount, "getAccountMarginCollateral");
    }
}
