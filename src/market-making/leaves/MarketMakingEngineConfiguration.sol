// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

library MarketMakingEngineConfiguration {
    /// @notice ERC7201 storage location.
    bytes32 internal constant MARKET_MAKING_ENGINE_CONFIGURATION_LOCATION =
        keccak256(abi.encode(uint256(keccak256("fi.zaros.market-making.MarketMakingEngineConfiguration")) - 1));

    // TODO: pack storage slots
    struct Data {
        uint256 slot;
    }

    /// @notice Loads the {MarketMakingEngineConfiguration}.
    /// @return marketMakingEngineConfiguration The loaded market making engine configuration storage pointer.
    function load() internal pure returns (Data storage marketMakingEngineConfiguration) {
        bytes32 slot = MARKET_MAKING_ENGINE_CONFIGURATION_LOCATION;
        assembly {
            marketMakingEngineConfiguration.slot := slot
        }
    }
}
