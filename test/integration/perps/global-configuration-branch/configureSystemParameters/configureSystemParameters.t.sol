// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { Base_Integration_Shared_Test } from "test/integration/shared/BaseIntegration.t.sol";
import { GlobalConfigurationBranch } from "@zaros/perpetuals/branches/GlobalConfigurationBranch.sol";
import { GlobalConfiguration } from "@zaros/perpetuals/leaves/GlobalConfiguration.sol";

contract ConfigureSystemParameters_Integration_Test is Base_Integration_Shared_Test {
    function setUp() public override {
        Base_Integration_Shared_Test.setUp();
        changePrank({ msgSender: users.owner });
        configureSystemParameters();

        createPerpMarkets();

        changePrank({ msgSender: users.naruto });
    }

    function test_RevertGiven_MaxPositionsPerAccountIsZero(
        uint128 marketOrderMaxLifetime,
        uint128 liquidationFeeUsdX18
    )
        external
    {
        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "maxPositionsPerAccount") });

        changePrank({ msgSender: users.owner });
        perpsEngine.configureSystemParameters(0, marketOrderMaxLifetime, liquidationFeeUsdX18);
    }

    modifier givenMaxPositionsPerAccountIsNotZero() {
        _;
    }

    function test_RevertWhen_MarketOrderMaxLifetimeIsZero(
        uint128 maxPositionsPerAccount,
        uint128 liquidationFeeUsdX18
    )
        external
        givenMaxPositionsPerAccountIsNotZero
    {
        vm.assume(maxPositionsPerAccount > 0);

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "marketOrderMaxLifetime") });

        changePrank({ msgSender: users.owner });
        perpsEngine.configureSystemParameters(maxPositionsPerAccount, 0, liquidationFeeUsdX18);
    }

    modifier givenMarketOrderMaxLifetimeIsNotZero() {
        _;
    }

    function test_RevertWhen_LiquidationFeeIsZero(
        uint128 maxPositionsPerAccount,
        uint128 marketOrderMaxLifetime
    )
        external
        givenMaxPositionsPerAccountIsNotZero
        givenMarketOrderMaxLifetimeIsNotZero
    {
        vm.assume(maxPositionsPerAccount > 0);
        vm.assume(marketOrderMaxLifetime > 0);

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "liquidationFeeUsdX18") });

        changePrank({ msgSender: users.owner });
        perpsEngine.configureSystemParameters(maxPositionsPerAccount, marketOrderMaxLifetime, 0);
    }

    function test_GivenLiquidationFeeIsNotZero(
        uint128 maxPositionsPerAccount,
        uint128 marketOrderMaxLifetime,
        uint128 liquidationFeeUsdX18
    )
        external
        givenMaxPositionsPerAccountIsNotZero
        givenMarketOrderMaxLifetimeIsNotZero
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
        perpsEngine.configureSystemParameters(maxPositionsPerAccount, marketOrderMaxLifetime, liquidationFeeUsdX18);

        GlobalConfiguration.Data storage globalConfiguration = GlobalConfiguration.load();
    }
}
