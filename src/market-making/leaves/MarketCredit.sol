// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

/// @dev A perp market won't be abl
library MarketCredit {
    // TODO: pack storage slots
    /// @param marketId The perps engine's linked market id.
    /// @param creditShare The market's share of the protocol total credit.
    /// @param autoDeleveragingThreshold A decimal rate which determines when the market should enter the
    /// auto-deleveraging state.
    /// @param autoDeleveragingFactor A decimal rate which determines how much should the market cut of the position's
    /// positive pnl. Goes from 0 to 1.
    /// @param autoDeleveragingScale An admin configurable value which determines how much should the auto
    /// deleveraging factor be.
    struct Data {
        uint256 marketId;
        uint256 creditShare;
        uint256 autoDeleveragingThreshold;
        uint256 autoDeleveragingFactor;
        uint256 autoDeleveragingScale;
    }
}
