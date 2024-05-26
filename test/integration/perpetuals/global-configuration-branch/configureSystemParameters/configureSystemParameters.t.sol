// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { Base_Test } from "test/Base.t.sol";
import { GlobalConfigurationBranch } from "@zaros/perpetuals/branches/GlobalConfigurationBranch.sol";
import { GlobalConfiguration } from "@zaros/perpetuals/leaves/GlobalConfiguration.sol";

contract ConfigureSystemParameters_Integration_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner });
        configureSystemParameters();

        createPerpMarkets();

        changePrank({ msgSender: users.naruto });
    }

    function testFuzz_RevertWhen_MaxPositionsPerAccountIsZero(
        uint128 marketOrderMaxLifetime,
        uint128 liquidationFeeUsdX18
    )
        external
    {
        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "maxPositionsPerAccount") });

        changePrank({ msgSender: users.owner });
        perpsEngine.configureSystemParameters(
            0,
            marketOrderMaxLifetime,
            liquidationFeeUsdX18,
            feeRecipients.marginCollateralRecipient,
            feeRecipients.orderFeeRecipient,
            feeRecipients.settlementFeeRecipient
        );
    }

    modifier whenMaxPositionsPerAccountIsNotZero() {
        _;
    }

    function testFuzz_RevertWhen_MarketOrderMaxLifetimeIsZero(
        uint128 maxPositionsPerAccount,
        uint128 liquidationFeeUsdX18
    )
        external
        whenMaxPositionsPerAccountIsNotZero
    {
        vm.assume(maxPositionsPerAccount > 0);

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "marketOrderMaxLifetime") });

        changePrank({ msgSender: users.owner });
        perpsEngine.configureSystemParameters(
            maxPositionsPerAccount,
            0,
            liquidationFeeUsdX18,
            feeRecipients.marginCollateralRecipient,
            feeRecipients.orderFeeRecipient,
            feeRecipients.settlementFeeRecipient
        );
    }

    modifier whenMarketOrderMaxLifetimeIsNotZero() {
        _;
    }

    function testFuzz_RevertWhen_LiquidationFeeIsZero(
        uint128 maxPositionsPerAccount,
        uint128 marketOrderMaxLifetime
    )
        external
        whenMaxPositionsPerAccountIsNotZero
        whenMarketOrderMaxLifetimeIsNotZero
    {
        vm.assume(maxPositionsPerAccount > 0);
        vm.assume(marketOrderMaxLifetime > 0);

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "liquidationFeeUsdX18") });

        changePrank({ msgSender: users.owner });
        perpsEngine.configureSystemParameters(
            maxPositionsPerAccount,
            marketOrderMaxLifetime,
            0,
            feeRecipients.marginCollateralRecipient,
            feeRecipients.orderFeeRecipient,
            feeRecipients.settlementFeeRecipient
        );
    }

    modifier whenLiquidationFeeIsNotZero() {
        _;
    }

    function testFuzz_RevertWhen_MarginCollateralRecipientIsZero(
        uint128 maxPositionsPerAccount,
        uint128 marketOrderMaxLifetime,
        uint128 liquidationFeeUsdX18
    )
        external
        whenMaxPositionsPerAccountIsNotZero
        whenMarketOrderMaxLifetimeIsNotZero
        whenLiquidationFeeIsNotZero
    {
        vm.assume(maxPositionsPerAccount > 0);
        vm.assume(marketOrderMaxLifetime > 0);
        vm.assume(liquidationFeeUsdX18 > 0);

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "marginCollateralRecipient") });

        changePrank({ msgSender: users.owner });
        perpsEngine.configureSystemParameters(
            maxPositionsPerAccount,
            marketOrderMaxLifetime,
            liquidationFeeUsdX18,
            address(0),
            feeRecipients.orderFeeRecipient,
            feeRecipients.settlementFeeRecipient
        );
    }

    modifier whenMarginCollateralRecipientIsNotZero() {
        _;
    }

    function testFuzz_RevertWhen_OrderFeeRecipientIsZero(
        uint128 maxPositionsPerAccount,
        uint128 marketOrderMaxLifetime,
        uint128 liquidationFeeUsdX18
    )
        external
        whenMaxPositionsPerAccountIsNotZero
        whenMarketOrderMaxLifetimeIsNotZero
        whenLiquidationFeeIsNotZero
        whenMarginCollateralRecipientIsNotZero
    {
        vm.assume(maxPositionsPerAccount > 0);
        vm.assume(marketOrderMaxLifetime > 0);
        vm.assume(liquidationFeeUsdX18 > 0);

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "orderFeeRecipient") });

        changePrank({ msgSender: users.owner });
        perpsEngine.configureSystemParameters(
            maxPositionsPerAccount,
            marketOrderMaxLifetime,
            liquidationFeeUsdX18,
            feeRecipients.marginCollateralRecipient,
            address(0),
            feeRecipients.settlementFeeRecipient
        );
    }

    modifier whenOrderFeeRecipientIsNotZero() {
        _;
    }

    function test_RevertWhen_SettlementFeeRecipientIsZero(
        uint128 maxPositionsPerAccount,
        uint128 marketOrderMaxLifetime,
        uint128 liquidationFeeUsdX18
    )
        external
        whenMaxPositionsPerAccountIsNotZero
        whenMarketOrderMaxLifetimeIsNotZero
        whenLiquidationFeeIsNotZero
        whenMarginCollateralRecipientIsNotZero
        whenOrderFeeRecipientIsNotZero
    {
        vm.assume(maxPositionsPerAccount > 0);
        vm.assume(marketOrderMaxLifetime > 0);
        vm.assume(liquidationFeeUsdX18 > 0);

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "settlementFeeRecipient") });

        changePrank({ msgSender: users.owner });
        perpsEngine.configureSystemParameters(
            maxPositionsPerAccount,
            marketOrderMaxLifetime,
            liquidationFeeUsdX18,
            feeRecipients.marginCollateralRecipient,
            feeRecipients.orderFeeRecipient,
            address(0)
        );
    }

    function test_WhenSettlementFeeRecipientIsNotZero(
        uint128 maxPositionsPerAccount,
        uint128 marketOrderMaxLifetime,
        uint128 liquidationFeeUsdX18
    )
        external
        whenMaxPositionsPerAccountIsNotZero
        whenMarketOrderMaxLifetimeIsNotZero
        whenLiquidationFeeIsNotZero
        whenMarginCollateralRecipientIsNotZero
        whenOrderFeeRecipientIsNotZero
    {
        vm.assume(maxPositionsPerAccount > 0);
        vm.assume(marketOrderMaxLifetime > 0);
        vm.assume(liquidationFeeUsdX18 > 0);

        // it should emit {LogConfigureSystemParameters} event
        vm.expectEmit({ emitter: address(perpsEngine) });
        emit GlobalConfigurationBranch.LogConfigureSystemParameters(
            users.owner, maxPositionsPerAccount, marketOrderMaxLifetime, liquidationFeeUsdX18
        );

        changePrank({ msgSender: users.owner });
        perpsEngine.configureSystemParameters(
            maxPositionsPerAccount,
            marketOrderMaxLifetime,
            liquidationFeeUsdX18,
            feeRecipients.marginCollateralRecipient,
            feeRecipients.orderFeeRecipient,
            feeRecipients.settlementFeeRecipient
        );
    }
}
