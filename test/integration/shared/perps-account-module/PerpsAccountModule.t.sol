// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";

abstract contract PerpsAccountModule_Integration_Shared_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        approveContracts();
        changePrank({ msgSender: users.naruto });
    }

    function _createAccountAndDeposit(uint256 amount) internal returns (uint256 accountId) {
        accountId = perpsEngine.createPerpsAccount();
        perpsEngine.depositMargin(accountId, address(usdToken), amount);
    }
}
