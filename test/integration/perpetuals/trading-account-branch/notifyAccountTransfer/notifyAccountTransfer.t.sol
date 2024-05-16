// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { Base_Integration_Shared_Test } from "test/integration/shared/BaseIntegration.t.sol";
import { TradingAccountBranch } from "@zaros/perpetuals/branches/TradingAccountBranch.sol";
import { TradingAccount } from "@zaros/perpetuals/leaves/TradingAccount.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

contract NotifyAccountTransfer_Integration_Test is Base_Integration_Shared_Test {
    function setUp() public override {
        Base_Integration_Shared_Test.setUp();
    }

    function test_RevertGiven_TheSenderIsNotTheAccountNftContract() external {
        changePrank({ msgSender: users.naruto });

        uint128 tradingAccountId = perpsEngine.createTradingAccount();

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.OnlyTradingAccountToken.selector, users.naruto) });

        perpsEngine.notifyAccountTransfer(users.madara, tradingAccountId);
    }

    function testFuzz_GivenTheSenderIsTheAccountNftContract(uint256 marginValueUsd) external {
        changePrank({ msgSender: users.naruto });

        marginValueUsd = bound({ x: marginValueUsd, min: USDZ_MIN_DEPOSIT_MARGIN, max: USDZ_DEPOSIT_CAP });
        deal({ token: address(usdToken), to: users.naruto, give: marginValueUsd });

        uint128 tradingAccountId = createAccountAndDeposit(marginValueUsd, address(usdToken));

        changePrank({ msgSender: address(tradingAccountToken) });

        // it should transfer the tradding account token
        perpsEngine.notifyAccountTransfer(users.madara, tradingAccountId);

        vm.expectRevert({
            revertData: abi.encodeWithSelector(Errors.AccountPermissionDenied.selector, tradingAccountId, users.naruto)
        });

        UD60x18 amount = ud60x18(marginValueUsd);

        // old user cannot withdraw
        changePrank({ msgSender: users.naruto });
        perpsEngine.withdrawMargin(tradingAccountId, address(usdToken), amount);

        // new user can withdraw
        changePrank({ msgSender: users.madara });
        perpsEngine.withdrawMargin(tradingAccountId, address(usdToken), amount);
    }
}
