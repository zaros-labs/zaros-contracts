// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Constants } from "@zaros/utils/Constants.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { Base_Test } from "test/Base.t.sol";
import { MarginCollateralConfiguration } from "@zaros/perpetuals/leaves/MarginCollateralConfiguration.sol";
import { MockPriceFeed } from "test/mocks/MockPriceFeed.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

contract MarginCollateralConfiguration_GetPrice_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner });
        configureSystemParameters();
        createPerpMarkets();
        changePrank({ msgSender: users.naruto });
    }

    function testFuzz_RevertWhen_PriceFeedIsZero(
        uint128 newDepositCap,
        uint120 newLoanToValue,
        uint8 newDecimals
    )
        external
    {
        address newPriceFeed = address(0);

        perpsEngine.exposed_configure(address(usdc), newDepositCap, newLoanToValue, newDecimals, newPriceFeed, MOCK_PRICE_FEED_HEARTBEAT_SECONDS);

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.CollateralPriceFeedNotDefined.selector) });

        perpsEngine.exposed_getPrice(address(usdc));
    }

    function test_WhenPriceFeedIsNotZero() external {
        UD60x18 price = perpsEngine.exposed_getPrice(address(usdc));

        MarginCollateralConfiguration.Data memory marginCollateralConfiguration =
            perpsEngine.exposed_MarginCollateral_load(address(usdc));

        uint8 priceFeedDecimals = MockPriceFeed(marginCollateralConfiguration.priceFeed).decimals();

        UD60x18 expectedPrice = ud60x18(MOCK_USDC_USD_PRICE * 10 ** (Constants.SYSTEM_DECIMALS - priceFeedDecimals));

        // it should return the price
        assertEq(expectedPrice.intoUint256(), price.intoUint256(), "price is not correct");
    }
}
