// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { Constants } from "@zaros/utils/Constants.sol";
import { Base_Test } from "test/Base.t.sol";
import { MockPriceFeed } from "test/mocks/MockPriceFeed.sol";

// PRB Math dependencies
import { sd59x18 } from "@prb-math/SD59x18.sol";
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

abstract contract PerpsAccountModule_Integration_Shared_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        approveContracts();
        changePrank({ msgSender: users.naruto });
    }

    function _createAccountAndDeposit(uint256 amount, address collateralType) internal returns (uint256 accountId) {
        accountId = perpsEngine.createPerpsAccount();
        perpsEngine.depositMargin(accountId, collateralType, amount);
    }

    function _getPrice(MockPriceFeed priceFeed) internal view returns (UD60x18) {
        uint8 decimals = priceFeed.decimals();
        (, int256 answer,,,) = priceFeed.latestRoundData();

        return ud60x18(uint256(answer) * 10 ** (Constants.DECIMALS - decimals));
    }
}
