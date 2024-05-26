// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Constants } from "@zaros/utils/Constants.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { Base_Test } from "test/Base.t.sol";
import { GlobalConfigurationBranch } from "@zaros/perpetuals/branches/GlobalConfigurationBranch.sol";
import { MockERC20 } from "test/mocks/MockERC20.sol";
import { MockERC20WithNoDecimals } from "test/mocks/MockERC20WithNoDecimals.sol";

// OpenZeppelin Upgradeable dependencies
import { ERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";

contract ConfigureMarginCollateral_Integration_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner });
        configureSystemParameters();
        createPerpMarkets();
        changePrank({ msgSender: users.naruto });
    }

    function testFuzz_RevertGiven_CollateralThatDoesNotHaveDecimals(
        uint128 depositCap,
        uint120 loanToValue,
        address priceFeed
    )
        external
    {
        changePrank({ msgSender: users.owner });

        MockERC20WithNoDecimals collateral =
            new MockERC20WithNoDecimals({ name: "Collateral", symbol: "COL", deployerBalance: 100_000_000e18 });

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                Errors.InvalidMarginCollateralConfiguration.selector, address(collateral), 0, priceFeed
            )
        });

        perpsEngine.configureMarginCollateral(address(collateral), depositCap, loanToValue, priceFeed);
    }

    modifier givenCollateralThatHasDecimals() {
        _;
    }

    function testFuzz_RevertWhen_CollateralDecimalsIsGreaterThanSystemDecimals(
        uint128 depositCap,
        uint120 loanToValue
    )
        external
        givenCollateralThatHasDecimals
    {
        changePrank({ msgSender: users.owner });

        uint8 decimals = Constants.SYSTEM_DECIMALS + 1;
        address priceFeed = address(0x20);

        MockERC20 collateral =
            new MockERC20({ name: "Collateral", symbol: "COL", decimals_: decimals, deployerBalance: 100_000_000e18 });

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                Errors.InvalidMarginCollateralConfiguration.selector, address(collateral), decimals, priceFeed
            )
        });

        perpsEngine.configureMarginCollateral(address(collateral), depositCap, loanToValue, priceFeed);
    }

    modifier givenCollateralDecimalsIsNotGreatherThanSystemDecimals() {
        _;
    }

    function testFuzz_RevertWhen_PriceFeedIsZero(
        uint128 depositCap,
        uint120 loanToValue
    )
        external
        givenCollateralThatHasDecimals
        givenCollateralDecimalsIsNotGreatherThanSystemDecimals
    {
        changePrank({ msgSender: users.owner });

        address priceFeed = address(0);

        MockERC20 collateral = new MockERC20({
            name: "Collateral",
            symbol: "COL",
            decimals_: Constants.SYSTEM_DECIMALS,
            deployerBalance: 100_000_000e18
        });

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                Errors.InvalidMarginCollateralConfiguration.selector,
                address(collateral),
                Constants.SYSTEM_DECIMALS,
                priceFeed
            )
        });

        perpsEngine.configureMarginCollateral(address(collateral), depositCap, loanToValue, priceFeed);
    }

    function testFuzz_GivenPriceFeedIsNotZero(
        uint128 depositCap,
        uint120 loanToValue
    )
        external
        givenCollateralThatHasDecimals
        givenCollateralDecimalsIsNotGreatherThanSystemDecimals
    {
        changePrank({ msgSender: users.owner });

        address priceFeed = address(0x20);

        MockERC20 collateral = new MockERC20({
            name: "Collateral",
            symbol: "COL",
            decimals_: Constants.SYSTEM_DECIMALS,
            deployerBalance: 100_000_000e18
        });

        // it should emit {LogConfigureMarginCollateral} event
        vm.expectEmit({ emitter: address(perpsEngine) });
        emit GlobalConfigurationBranch.LogConfigureMarginCollateral(
            users.owner, address(collateral), depositCap, Constants.SYSTEM_DECIMALS, priceFeed
        );

        // it should configure
        perpsEngine.configureMarginCollateral(address(collateral), depositCap, loanToValue, priceFeed);
    }
}
