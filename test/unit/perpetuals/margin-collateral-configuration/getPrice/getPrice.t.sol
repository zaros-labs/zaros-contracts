// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Constants } from "@zaros/utils/Constants.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { Base_Test } from "test/Base.t.sol";
import { MarginCollateralConfiguration } from "@zaros/perpetuals/leaves/MarginCollateralConfiguration.sol";
import { MockPriceFeed } from "test/mocks/MockPriceFeed.sol";
import { MockPriceFeedWithInvalidReturn } from "test/mocks/MockPriceFeedWithInvalidReturn.sol";
import { MockPriceFeedOldUpdatedAt } from "test/mocks/MockPriceFeedOldUpdatedAt.sol";
import { MockSequencerUptimeFeedWithInvalidReturn } from "test/mocks/MockSequencerUptimeFeedWithInvalidReturn.sol";
import { MockSequencerUptimeFeedDown } from "test/mocks/MockSequencerUptimeFeedDown.sol";

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

        perpsEngine.exposed_configure(
            address(usdc), newDepositCap, newLoanToValue, newDecimals, newPriceFeed, MOCK_PRICE_FEED_HEARTBEAT_SECONDS
        );

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.CollateralPriceFeedNotDefined.selector) });

        perpsEngine.exposed_getPrice(address(usdc));
    }

    modifier whenPriceFeedIsNotZero() {
        _;
    }

    function test_RevertWhen_PriceFeedDecimalsIsGreaterThanTheSystemDecimals() external whenPriceFeedIsNotZero {
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

    modifier whenPriceFeedDecimalsIsLessThanOrEqualToTheSystemDecimals() {
        _;
    }

    function test_RevertWhen_SequencerUptimeFeedReturnsAInvalidValue()
        external
        whenPriceFeedIsNotZero
        whenPriceFeedDecimalsIsLessThanOrEqualToTheSystemDecimals
    {
        address collateral = address(wstEth);

        changePrank({ msgSender: users.owner });
        MockSequencerUptimeFeedWithInvalidReturn mockSequencerUptimeFeedWithInvalidReturn =
            new MockSequencerUptimeFeedWithInvalidReturn();
        perpsEngine.setSequencerUptimeFeed(address(mockSequencerUptimeFeedWithInvalidReturn));

        changePrank({ msgSender: users.naruto });

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.InvalidSequencerUptimeFeedReturn.selector) });

        perpsEngine.exposed_getPrice(collateral);
    }

    modifier whenSequencerUptimeFeedReturnsAValidValue() {
        _;
    }

    function test_RevertWhen_SequncerUptimeFeedIsDown()
        external
        whenPriceFeedIsNotZero
        whenPriceFeedDecimalsIsLessThanOrEqualToTheSystemDecimals
        whenSequencerUptimeFeedReturnsAValidValue
    {
        address collateral = address(wstEth);

        changePrank({ msgSender: users.owner });
        MockSequencerUptimeFeedDown mockSequencerUptimeFeedDown = new MockSequencerUptimeFeedDown();
        perpsEngine.setSequencerUptimeFeed(address(mockSequencerUptimeFeedDown));

        changePrank({ msgSender: users.naruto });

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                Errors.OracleSequencerUptimeFeedIsDown.selector, address(mockSequencerUptimeFeedDown)
            )
        });

        perpsEngine.exposed_getPrice(collateral);
    }

    modifier whenSequencerUptimeFeedIsUp() {
        _;
    }

    function test_RevertWhen_PriceFeedReturnsAInvalidValueFromLatestRoundData()
        external
        whenPriceFeedIsNotZero
        whenPriceFeedDecimalsIsLessThanOrEqualToTheSystemDecimals
        whenSequencerUptimeFeedReturnsAValidValue
        whenSequencerUptimeFeedIsUp
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

    modifier whenPriceFeedReturnsAValidValueFromLatestRoundData() {
        _;
    }

    function test_RevertWhen_TheDifferenceOfBlockTimestampMinusUpdateAtIsGreaterThanThePriceFeedHearbetSeconds()
        external
        whenPriceFeedIsNotZero
        whenPriceFeedDecimalsIsLessThanOrEqualToTheSystemDecimals
        whenSequencerUptimeFeedReturnsAValidValue
        whenSequencerUptimeFeedIsUp
        whenPriceFeedReturnsAValidValueFromLatestRoundData
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
        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                Errors.OraclePriceFeedHeartbeat.selector, address(mockPriceFeedOldUpdatedAt)
            )
        });

        perpsEngine.exposed_getPrice(collateral);
    }

    function test_WhenTheDifferenceOfBlockTimestampMinusUpdateAtIsLessThanOrEqualThanThePriceFeedHeartbetSeconds()
        external
        whenPriceFeedIsNotZero
        whenPriceFeedDecimalsIsLessThanOrEqualToTheSystemDecimals
        whenSequencerUptimeFeedReturnsAValidValue
        whenSequencerUptimeFeedIsUp
        whenPriceFeedReturnsAValidValueFromLatestRoundData
    {
        UD60x18 price = perpsEngine.exposed_getPrice(address(wstEth));

        uint8 priceFeedDecimals = MockPriceFeed(marginCollaterals[WSTETH_MARGIN_COLLATERAL_ID].priceFeed).decimals();

        UD60x18 expectedPrice = ud60x18(
            marginCollaterals[WSTETH_MARGIN_COLLATERAL_ID].mockUsdPrice
                * 10 ** (Constants.SYSTEM_DECIMALS - priceFeedDecimals)
        );

        // it should return the price
        assertEq(expectedPrice.intoUint256(), price.intoUint256(), "price is not correct");
    }
}
