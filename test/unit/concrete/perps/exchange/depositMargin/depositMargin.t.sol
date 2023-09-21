// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { IPerpsAccountModule } from "@zaros/markets/perps/interfaces/IPerpsAccountModule.sol";
import { PerpsAccount } from "@zaros/markets/perps/storage/PerpsAccount.sol";
import { ParameterError } from "@zaros/utils/Errors.sol";
import { Base_Test } from "test/Base.t.sol";

contract DepositMargin_Unit_Concrete_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
        approveContracts();
        changePrank({ msgSender: users.naruto });
    }

    function test_CollateralNotEnabled() external {
        changePrank({ msgSender: users.owner });
        perpsExchange.setIsCollateralEnabled(address(usdToken), false);
        changePrank({ msgSender: users.naruto });

        uint256 amountToDeposit = 100e18;
        uint256 userPerpsAccountId = perpsExchange.createPerpsAccount();

        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                IPerpsAccountModule.Zaros_PerpsAccountModule_InvalidCollateralType.selector, address(usdToken)
                )
        });

        perpsExchange.depositMargin(userPerpsAccountId, address(usdToken), amountToDeposit);
    }

    modifier whenCollateralIsEnabled() {
        _;
    }

    function test_AmountZero() external whenCollateralIsEnabled {
        uint256 amountToDeposit = 0;
        uint256 userPerpsAccountId = perpsExchange.createPerpsAccount();

        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                ParameterError.Zaros_InvalidParameter.selector, "amount", "amount can't be zero"
                )
        });

        perpsExchange.depositMargin(userPerpsAccountId, address(usdToken), amountToDeposit);
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

        perpsExchange.depositMargin(userPerpsAccountId, address(usdToken), amountToDeposit);
    }

    function test_PerpsAccountExists() external whenCollateralIsEnabled givenAmountIsNotZero {
        uint256 amountToDeposit = 100e18;
        uint256 userPerpsAccountId = perpsExchange.createPerpsAccount();

        vm.expectEmit({ emitter: address(perpsExchange) });
        emit LogDepositMargin(users.naruto, userPerpsAccountId, address(usdToken), amountToDeposit);
        expectCallToTransferFrom(usdToken, users.naruto, address(perpsExchange), amountToDeposit);
        perpsExchange.depositMargin(userPerpsAccountId, address(usdToken), amountToDeposit);

        uint256 newMarginCollateral =
            perpsExchange.getAccountMarginCollateral(userPerpsAccountId, address(usdToken)).intoUint256();
        assertEq(newMarginCollateral, amountToDeposit);
    }
}
