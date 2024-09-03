// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { FeeRecipient } from "@zaros/market-making/leaves/FeeRecipient.sol";
import { Errors } from "@zaros/utils/Errors.sol";

// Open Zeppelin dependencies
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";

library MarketMakingEngineConfiguration {
    using EnumerableSet for EnumerableSet.UintSet;

    /// @notice ERC7201 storage location.
    bytes32 internal constant MARKET_MAKING_ENGINE_CONFIGURATION_LOCATION =
        keccak256(abi.encode(uint256(keccak256("fi.zaros.market-making.MarketMakingEngineConfiguration")) - 1));

    // TODO: pack storage slots
    struct Data {
        address usdz;
        address usdc;
        address weth;
        address perpsEngine;
        address feeDistributor;
        FeeRecipient.Data[][] feeRecipients;
        mapping(uint256 chainId => address sequencerUptimeFeed) sequencerUptimeFeedByChainId;
        // TODO: define roles
        mapping(address keeper => bool isEnabled) isSystemKeeperEnabled;
        EnumerableSet.UintSet enabledVaultsIds;
    }

    /// @notice Loads the {MarketMakingEngineConfiguration} namespace.
    /// @return marketMakingEngineConfiguration The loaded market making engine configuration storage pointer.
    function load() internal pure returns (Data storage marketMakingEngineConfiguration) {
        bytes32 slot = MARKET_MAKING_ENGINE_CONFIGURATION_LOCATION;
        assembly {
            marketMakingEngineConfiguration.slot := slot
        }
    }

    /// @notice Adds a new vault to the enabled vault set.
    /// @param self The market making engine configuration storage pointer.
    /// @param vaultId The id of the vault to add.
    function addVault(Data storage self, uint256 vaultId) internal {
        bool added = self.enabledVaultsIds.add(uint256(vaultId));

        if (!added) {
            revert Errors.VaulttAlreadyEnabled(vaultId);
        }
    }
}
