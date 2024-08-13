// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

/// @dev A perp market won't be abl
library MarketCredit {
    /// @notice ERC7201 storage location.
    bytes32 internal constant MARKET_CREDIT_LOCATION =
        keccak256(abi.encode(uint256(keccak256("fi.zaros.market-making.Swap")) - 1));

    // TODO: pack storage slots
    // TODO: add heap of in range and out range Vaults that provide credit to this market.
    /// @param marketId The perps engine's linked market id.
    /// @param creditShare The market's share of the protocol total credit.
    /// @param autoDeleveragingFactor A decimal rate which determines how much should the market cut of the position's
    /// positive pnl. Goes from 0 to 1.
    /// @param autoDeleveragingThreshold An admin configurable decimal rate which determines when the market should
    /// enter the auto deleveraging state. Goes from 0 to 1.
    /// @param autoDeleveragingScale An admin configurable value which determines how much should the auto
    /// deleveraging factor be.
    struct Data {
        uint256 marketId;
        uint256 creditShare;
        uint256 autoDeleveragingThreshold;
        uint256 autoDeleveragingFactor;
        uint256 autoDeleveragingScale;
    }

    /// @notice Loads a {MarketCredit} namespace.
    /// @param marketId The perp market id.
    /// @return marketCredit The loaded market credit storage pointer.
    function load(uint256 marketId) internal pure returns (Data storage marketCredit) {
        bytes32 slot = keccak256(abi.encode(MARKET_CREDIT_LOCATION, marketId));
        assembly {
            marketCredit.slot := slot
        }
    }
}
