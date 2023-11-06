// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { Base_Integration_Shared_Test } from "test/integration/shared/BaseIntegration.t.sol";
import { IPerpsAccountModule } from "@zaros/markets/perps/interfaces/IPerpsAccountModule.sol";
import { PerpsAccount } from "@zaros/markets/perps/storage/PerpsAccount.sol";
import { ParameterError } from "@zaros/utils/Errors.sol";

contract DepositMargin_Integration_Test is Base_Integration_Shared_Test {
    function setUp() public override {
        Base_Integration_Shared_Test.setUp();
    }

    function testFuzz_CollateralNotEnabled(uint256 amountToDeposit) external {
        amountToDeposit = bound({ x: amountToDeposit, min: 1, max: ZRSUSD_DEPOSIT_CAP });
        deal({ token: address(usdToken), to: users.naruto, give: amountToDeposit });

        changePrank({ msgSender: users.owner });
        perpsEngine.configureCollateral(address(usdToken), 0);
        changePrank({ msgSender: users.naruto });

        uint256 userPerpsAccountId = perpsEngine.createPerpsAccount();

        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                IPerpsAccountModule.Zaros_PerpsAccountModule_DepositCap.selector, address(usdToken), amountToDeposit, 0
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

    function testFuzz_PerpsAccountDoesNotExist(
        uint256 amountToDeposit,
        uint256 userPerpsAccountId
    )
        external
        whenCollateralIsEnabled
        givenAmountIsNotZero
    {
        amountToDeposit = bound({ x: amountToDeposit, min: 1, max: ZRSUSD_DEPOSIT_CAP });
        deal({ token: address(usdToken), to: users.naruto, give: amountToDeposit });

        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                PerpsAccount.Zaros_PerpsAccount_AccountNotFound.selector, userPerpsAccountId, users.naruto
                )
        });

        perpsEngine.depositMargin(userPerpsAccountId, address(usdToken), amountToDeposit);
    }

    function testFuzz_PerpsAccountExists(uint256 amountToDeposit)
        external
        whenCollateralIsEnabled
        givenAmountIsNotZero
    {
        amountToDeposit = bound({ x: amountToDeposit, min: 1, max: ZRSUSD_DEPOSIT_CAP });
        deal({ token: address(usdToken), to: users.naruto, give: amountToDeposit });

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
