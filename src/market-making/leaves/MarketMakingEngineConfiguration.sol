// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { FeeRecipient } from "@zaros/market-making/leaves/FeeRecipient.sol";

library MarketMakingEngineConfiguration {
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
        address[][] feeRecipients;
        // FeeRecipient.Data[][] feeRecipients;
        mapping(uint256 chainId => address sequencerUptimeFeed) sequencerUptimeFeedByChainId;
        // TODO: define roles
        mapping(address keeper => bool isEnabled) isSystemKeeperEnabled;
    }

    /// @notice Loads the {MarketMakingEngineConfiguration} namespace.
    /// @return marketMakingEngineConfiguration The loaded market making engine configuration storage pointer.
    function load() internal pure returns (Data storage marketMakingEngineConfiguration) {
        bytes32 slot = MARKET_MAKING_ENGINE_CONFIGURATION_LOCATION;
        assembly {
            marketMakingEngineConfiguration.slot := slot
        }
    }
}
