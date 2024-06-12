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

contract MockPriceFeedWithInvalidReturn {
    function decimals() public pure returns (uint8) {
        return Constants.SYSTEM_DECIMALS;
    }

    function latestRoundData() external pure {
        revert();
    }
}

contract MockPriceFeedOldUpdatedAt {
    function decimals() public pure returns (uint8) {
        return Constants.SYSTEM_DECIMALS;
    }

    function latestRoundData()
        external
        pure
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (0, 0, 0, 1, 0);
    }
}

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

    modifier whenPriceFeedIsNotZero() {
        _;
    }

    function test_RevertWhen_PriceFeedDecimalsIsGreatherThanTheSystemDecimals() external whenPriceFeedIsNotZero {
        address collateral = address(wstEth);

        MockPriceFeed mockPriceFeed = new MockPriceFeed(Constants.SYSTEM_DECIMALS + 1, int256(MOCK_USDC_USD_PRICE));

        perpsEngine.exposed_configure(
            collateral,
            WSTETH_DEPOSIT_CAP,
            WSTETH_LOAN_TO_VALUE,
            Constants.SYSTEM_DECIMALS,
            address(mockPriceFeed),
            MOCK_PRICE_FEED_HEARTBEAT_SECONDS
        );

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.InvalidOracleReturn.selector) });

        perpsEngine.exposed_getPrice(collateral);
    }

    modifier whenPriceFeedDecimalsIsLessOrEqualThanTheSystemDecimals() {
        _;
    }

    function test_RevertWhen_PriceFeedReturnAInvalidValueFromLatestRoundData()
        external
        whenPriceFeedIsNotZero
        whenPriceFeedDecimalsIsLessOrEqualThanTheSystemDecimals
    {
        address collateral = address(wstEth);

        MockPriceFeedWithInvalidReturn mockPriceFeedWithInvalidReturn = new MockPriceFeedWithInvalidReturn();

        perpsEngine.exposed_configure(
            collateral,
            WSTETH_DEPOSIT_CAP,
            WSTETH_LOAN_TO_VALUE,
            Constants.SYSTEM_DECIMALS,
            address(mockPriceFeedWithInvalidReturn),
            MOCK_PRICE_FEED_HEARTBEAT_SECONDS
        );

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.InvalidOracleReturn.selector) });

        perpsEngine.exposed_getPrice(collateral);
    }

    modifier whenPriceFeedReturnAValidValueFromLatestRoundData() {
        _;
    }

    function test_RevertWhen_TheDifferenceOfBlockTimestampLessUpdateAtIsGreatherThanThePriceFeedHearbetSeconds()
        external
        whenPriceFeedIsNotZero
        whenPriceFeedDecimalsIsLessOrEqualThanTheSystemDecimals
        whenPriceFeedReturnAValidValueFromLatestRoundData
    {
        address collateral = address(wstEth);

        MockPriceFeedOldUpdatedAt mockPriceFeedOldUpdatedAt = new MockPriceFeedOldUpdatedAt();

        perpsEngine.exposed_configure(
            collateral,
            WSTETH_DEPOSIT_CAP,
            WSTETH_LOAN_TO_VALUE,
            Constants.SYSTEM_DECIMALS,
            address(mockPriceFeedOldUpdatedAt),
            MOCK_PRICE_FEED_HEARTBEAT_SECONDS
        );

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.OraclePriceFeedHeartbeat.selector) });

        perpsEngine.exposed_getPrice(collateral);
    }

    function test_WhenTheDifferenceOfBlockTimestampLessUpdateAtIsLessOrEqualThanThePriceFeedHearbetSeconds()
        external
        whenPriceFeedIsNotZero
        whenPriceFeedDecimalsIsLessOrEqualThanTheSystemDecimals
        whenPriceFeedReturnAValidValueFromLatestRoundData
    {
        UD60x18 price = perpsEngine.exposed_getPrice(address(wstEth));

        MarginCollateralConfiguration.Data memory marginCollateralConfiguration =
            perpsEngine.exposed_MarginCollateral_load(address(usdc));

        uint8 priceFeedDecimals = MockPriceFeed(marginCollateralConfiguration.priceFeed).decimals();

        UD60x18 expectedPrice = ud60x18(MOCK_USDC_USD_PRICE * 10 ** (Constants.SYSTEM_DECIMALS - priceFeedDecimals));

        // it should return the price
        assertEq(expectedPrice.intoUint256(), price.intoUint256(), "price is not correct");
    }
}
