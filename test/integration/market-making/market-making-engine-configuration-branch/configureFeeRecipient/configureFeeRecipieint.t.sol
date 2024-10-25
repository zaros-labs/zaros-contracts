// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { MarketMakingEngineConfigurationBranch } from
    "@zaros/market-making/branches/MarketMakingEngineConfigurationBranch.sol";
import { Constants } from "@zaros/utils/Constants.sol";

// Zaros dependencies test
import { Base_Test } from "test/Base.t.sol";

// PRB Math dependencies
import { UD60x18, ud60x18, convert as convertToUd60x18 } from "@prb-math/UD60x18.sol";

// Open Zeppelin dependencies
import { Ownable } from "@openzeppelin/access/Ownable.sol";

contract MarketMakingEngineConfigurationBranch_ConfigureFeeRecipient_Integration_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });

        marketMakingEngine.configureFeeRecipient(MOCK_CONFIGURATION_FEE_RECIPIENT, address(perpsEngine), 0);
    }

    function testFuzz_RevertGiven_TheSenderIsNotTheOwner(uint256 configuration) external {
        changePrank({ msgSender: users.sakura.account });

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.sakura.account)
        });

        marketMakingEngine.configureFeeRecipient(configuration, users.naruto.account, 1e18);
    }

    modifier givenTheSenderIsTheOwner() {
        _;
    }

    function testFuzz_RevertWhen_TheFeeRecipientIsZero(uint256 configuration) external givenTheSenderIsTheOwner {
        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "feeRecipient") });

        marketMakingEngine.configureFeeRecipient(configuration, address(0), 1e18);
    }

    modifier whenFeeRecipientIsNotZero() {
        _;
    }

    function testFuzz_RevertWhen_TheTotalOfFeeRecipientsShareIsGreaterThenTheMaxOfShares(
        uint256 randomConfiguration,
        uint256 quantityOfConfigurations,
        uint256 quantityOfFeeRecipientsPerConfigurations
    )
        external
        givenTheSenderIsTheOwner
        whenFeeRecipientIsNotZero
    {
        UD60x18 maxOfSharesX18 = ud60x18(Constants.MAX_OF_SHARES);

        quantityOfConfigurations = bound({ x: quantityOfConfigurations, min: 1, max: 10 });
        quantityOfFeeRecipientsPerConfigurations =
            bound({ x: quantityOfFeeRecipientsPerConfigurations, min: 1, max: 10 });

        UD60x18 quantityTotalOfFeeRecipientsX18 =
            convertToUd60x18(quantityOfConfigurations).mul(convertToUd60x18(quantityOfFeeRecipientsPerConfigurations));

        UD60x18 sharePerFeeRecipientX18 = maxOfSharesX18.div(quantityTotalOfFeeRecipientsX18);

        for (uint256 i = 0; i < quantityOfConfigurations; i++) {
            for (uint256 j = 0; j < quantityOfFeeRecipientsPerConfigurations; j++) {
                marketMakingEngine.configureFeeRecipient(
                    i, address(uint160(j + 1)), sharePerFeeRecipientX18.intoUint256()
                );
            }
        }

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.FeeRecipientShareExceedsOne.selector) });
        marketMakingEngine.configureFeeRecipient(
            randomConfiguration, users.naruto.account, maxOfSharesX18.intoUint256()
        );
    }

    function testFuzz_WhenTheTotalOfFeeRecipientsShareIsLessOrEqualThenTheMaxOfShares(
        uint256 quantityOfConfigurations,
        uint256 quantityOfFeeRecipientsPerConfigurations
    )
        external
        givenTheSenderIsTheOwner
        whenFeeRecipientIsNotZero
    {
        UD60x18 maxOfSharesX18 = ud60x18(Constants.MAX_OF_SHARES);

        quantityOfConfigurations = bound({ x: quantityOfConfigurations, min: 1, max: 10 });
        quantityOfFeeRecipientsPerConfigurations =
            bound({ x: quantityOfFeeRecipientsPerConfigurations, min: 1, max: 10 });

        UD60x18 quantityTotalOfFeeRecipientsX18 =
            convertToUd60x18(quantityOfConfigurations).mul(convertToUd60x18(quantityOfFeeRecipientsPerConfigurations));

        UD60x18 sharePerFeeRecipientX18 = maxOfSharesX18.div(quantityTotalOfFeeRecipientsX18);

        for (uint256 i; i < quantityOfConfigurations; i++) {
            for (uint256 j; j < quantityOfFeeRecipientsPerConfigurations; j++) {
                uint256 configuration = i;
                address feeRecipient = address(uint160(j + 1));
                uint256 share = sharePerFeeRecipientX18.intoUint256();

                // it should emit {LogConfigureFeeRecipient} event
                vm.expectEmit({ emitter: address(marketMakingEngine) });
                emit MarketMakingEngineConfigurationBranch.LogConfigureFeeRecipient(
                    configuration, feeRecipient, share
                );

                marketMakingEngine.configureFeeRecipient(configuration, feeRecipient, share);
            }
        }

        for (uint256 i; i < quantityOfConfigurations; i++) {
            uint256 configuration = i;
            // it should set the configuration fee recipient in the storage
            assertEq(
                marketMakingEngine.workaround_getIfConfigurationExistsInTheFeeRecipients(configuration),
                true,
                "the configuration fee recipient should be set in the storage"
            );

            for (uint256 j; j < quantityOfFeeRecipientsPerConfigurations; j++) {
                address feeRecipient = address(uint160(j + 1));

                // it should set the protocol fee recipients in the storage
                assertEq(
                    marketMakingEngine.workaround_getFeeRecipientShare(configuration, feeRecipient),
                    sharePerFeeRecipientX18.intoUint256(),
                    "the protocol fee recipient share should be set in the storage"
                );
            }
        }
    }
}
