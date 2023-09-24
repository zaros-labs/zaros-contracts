// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { PerpsAccountModule_Integration_Shared_Test } from
    "test/integration/shared/perps-account-module/PerpsAccountModule.t.sol";
import { IPerpsAccountModule } from "@zaros/markets/perps/interfaces/IPerpsAccountModule.sol";
import { PerpsAccount } from "@zaros/markets/perps/storage/PerpsAccount.sol";
import { ParameterError } from "@zaros/utils/Errors.sol";

contract DepositMargin_Integration_Concrete_Test is PerpsAccountModule_Integration_Shared_Test {
    function setUp() public override {
        PerpsAccountModule_Integration_Shared_Test.setUp();
    }

    function test_CollateralNotEnabled() external {
        changePrank({ msgSender: users.owner });
        perpsEngine.setIsCollateralEnabled(address(usdToken), false);
        changePrank({ msgSender: users.naruto });

        uint256 amountToDeposit = 100e18;
        uint256 userPerpsAccountId = perpsEngine.createPerpsAccount();

        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                IPerpsAccountModule.Zaros_PerpsAccountModule_InvalidCollateralType.selector, address(usdToken)
                )
        });

        perpsEngine.depositMargin(userPerpsAccountId, address(usdToken), amountToDeposit);
    }

    modifier whenCollateralIsEnabled() {
        _;
    }

    function test_AmountZero() external whenCollateralIsEnabled {
        uint256 amountToDeposit = 0;
        uint256 userPerpsAccountId = perpsEngine.createPerpsAccount();

        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                ParameterError.Zaros_InvalidParameter.selector, "amount", "amount can't be zero"
                )
        });

        perpsEngine.depositMargin(userPerpsAccountId, address(usdToken), amountToDeposit);
    }

    modifier givenAmountIsNotZero() {
        _;
    }

    function test_PerpsAccountDoesNotExist() external whenCollateralIsEnabled givenAmountIsNotZero {
        uint256 amountToDeposit = 100e18;
        uint256 userPerpsAccountId = 0;

        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                PerpsAccount.Zaros_PerpsAccount_AccountNotFound.selector, userPerpsAccountId, users.naruto
                )
        });

        perpsEngine.depositMargin(userPerpsAccountId, address(usdToken), amountToDeposit);
    }

    function test_PerpsAccountExists() external whenCollateralIsEnabled givenAmountIsNotZero {
        uint256 amountToDeposit = 100e18;
        uint256 userPerpsAccountId = perpsEngine.createPerpsAccount();

        vm.expectEmit({ emitter: address(perpsEngine) });
        emit LogDepositMargin(users.naruto, userPerpsAccountId, address(usdToken), amountToDeposit);
        expectCallToTransferFrom(usdToken, users.naruto, address(perpsEngine), amountToDeposit);
        perpsEngine.depositMargin(userPerpsAccountId, address(usdToken), amountToDeposit);

        uint256 newMarginCollateral =
            perpsEngine.getAccountMarginCollateral(userPerpsAccountId, address(usdToken)).intoUint256();
        assertEq(newMarginCollateral, amountToDeposit, "depositMargin");
    }
}
