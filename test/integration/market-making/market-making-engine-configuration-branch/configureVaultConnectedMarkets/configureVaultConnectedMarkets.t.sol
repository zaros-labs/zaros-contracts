// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { MarketMakingEngineConfigurationBranch } from
    "@zaros/market-making/branches/MarketMakingEngineConfigurationBranch.sol";

// Zaros dependencies test
import { Base_Test } from "test/Base.t.sol";

// Open Zeppelin dependencies
import { Ownable } from "@openzeppelin/access/Ownable.sol";

contract MarketMakingEngineConfigurationBranch_ConfigureVaultConnectedMarkets_Integration_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
    }

    function testFuzz_RevertGiven_TheSenderIsNotTheOwner(uint256 vaultId) external {
        changePrank({ msgSender: users.sakura.account });

        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.sakura.account)
        });

        marketMakingEngine.configureVaultConnectedMarkets(fuzzVaultConfig.vaultId, new uint128[](1));
    }

    modifier givenTheSenderIsTheOwner() {
        _;
    }

    function test_RevertWhen_VaultIdIsZero() external givenTheSenderIsTheOwner {
        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "vaultId") });

        uint128 vaultId = 0;

        marketMakingEngine.configureVaultConnectedMarkets(vaultId, new uint128[](1));
    }

    modifier whenVaultIdIsNotZero() {
        _;
    }

    function testFuzz_RevertWhen_ConnectedMarketsArrayLengthIsZero(
        uint256 vaultId
    )
        external
        givenTheSenderIsTheOwner
        whenVaultIdIsNotZero
    {
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "connectedMarketsIds") });

        marketMakingEngine.configureVaultConnectedMarkets(fuzzVaultConfig.vaultId, new uint128[](0));
    }

    function testFuzz_WhenConnectedMarketsArrayLengthIsNotZero(
        uint256 vaultId,
        uint256 numberOfConnectedMarketsIds
    )
        external
        givenTheSenderIsTheOwner
        whenVaultIdIsNotZero
    {
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        numberOfConnectedMarketsIds = bound({ x: numberOfConnectedMarketsIds, min: 1, max: 10 });

        uint128[] memory fuzzingConnectedMarketsIds = new uint128[](numberOfConnectedMarketsIds);

        for (uint256 i; i < numberOfConnectedMarketsIds; i++) {
            fuzzingConnectedMarketsIds[i] = uint128(i + 1);
        }

        // it should emit {LogConfigureVaultConnectedMarkets} event
        vm.expectEmit({ emitter: address(marketMakingEngine) });
        emit MarketMakingEngineConfigurationBranch.LogConfigureVaultConnectedMarkets(
            fuzzVaultConfig.vaultId, fuzzingConnectedMarketsIds
        );

        marketMakingEngine.configureVaultConnectedMarkets(fuzzVaultConfig.vaultId, fuzzingConnectedMarketsIds);

        // it should update the vault storage
        uint128[] memory connectedMarkets =
            marketMakingEngine.workaround_Vault_getConnectedMarkets(fuzzVaultConfig.vaultId);

        for (uint256 i; i < fuzzingConnectedMarketsIds.length; i++) {
            assertEq(connectedMarkets[i], fuzzingConnectedMarketsIds[i], "the connected market id should be updated");
        }
    }
}
