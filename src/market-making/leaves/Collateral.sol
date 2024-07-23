// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

library Collateral {
    /// @notice ERC7201 storage location.
    bytes32 internal constant COLLATERAL_LOCATION =
        keccak256(abi.encode(uint256(keccak256("fi.zaros.market-making.Collateral")) - 1));

    // TODO: pack storage slots
    struct Data {
        uint256 creditRatio;
        uint32 priceFeedHeartbeatSeconds;
        address priceFeed;
        address asset;
    }

    /// @notice Loads a {Collateral}.
    /// @param asset The collateral asset address.
    /// @return collateral The loaded collateral storage pointer.
    function load(address asset) internal pure returns (Data storage collateral) {
        bytes32 slot = keccak256(abi.encode(asset));
        assembly {
            collateral.slot := slot
        }
    }
}
