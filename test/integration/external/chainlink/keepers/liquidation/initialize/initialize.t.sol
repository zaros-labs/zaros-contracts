// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { Base_Integration_Shared_Test } from "test/integration/shared/BaseIntegration.t.sol";
import { LiquidationKeeper } from "@zaros/external/chainlink/keepers/liquidation/LiquidationKeeper.sol";

// Open Zeppelin dependencies
import { ERC1967Proxy } from "@openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";

contract LiquidationKeeper_Integration_Test is Base_Integration_Shared_Test {
    function setUp() public override {
        Base_Integration_Shared_Test.setUp();
        changePrank({ msgSender: users.owner });
        configureSystemParameters();

        createPerpMarkets();

        changePrank({ msgSender: users.naruto });
    }

    modifier givenInitializeContractWithSomeWrongInformation() {
        _;
    }

    function test_RevertWhen_AddressOfMarginCollateralRecipientIsZero()
        external
        givenInitializeContractWithSomeWrongInformation
    {
        address liquidationKeeperImplementation = address(new LiquidationKeeper());

        address marginCollateralRecipient = address(0);
        address liquidationFeeRecipient = address(0x123);

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "marginCollateralRecipient") });

        new ERC1967Proxy(
            liquidationKeeperImplementation,
            abi.encodeWithSelector(
                LiquidationKeeper.initialize.selector, users.owner, marginCollateralRecipient, liquidationFeeRecipient
            )
        );
    }

    function test_RevertWhen_AddressOfLiquidationFeeRecipientIsZero()
        external
        givenInitializeContractWithSomeWrongInformation
    {
        address liquidationKeeperImplementation = address((new LiquidationKeeper()));

        address marginCollateralRecipient = address(0x123);
        address liquidationFeeRecipient = address(0);

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "liquidationFeeRecipient") });

        new ERC1967Proxy(
            liquidationKeeperImplementation,
            abi.encodeWithSelector(
                LiquidationKeeper.initialize.selector, users.owner, marginCollateralRecipient, liquidationFeeRecipient
            )
        );
    }
}
