// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Distribution } from "./Distribution.sol";

// PRB Math dependencies
import { UD60x18 } from "@prb-math/UD60x18.sol";

// Solady dependencies
import { MinHeapLib } from "@solady/Milady.sol";

/// @dev A perp market won't be abl
library MarketCredit {
    /// @notice ERC7201 storage location.
    bytes32 internal constant MARKET_CREDIT_LOCATION =
        keccak256(abi.encode(uint256(keccak256("fi.zaros.market-making.MarketCredit")) - 1));

    // TODO: pack storage slots
    // TODO: add heap of in range and out range Vaults that provide credit to this market.
    /// @param marketId The perps engine's linked market id.
    /// @param autoDeleverageThreshold An admin configurable decimal rate which determines when the market should
    /// enter the auto deleverage state. Goes from 0 to 1.
    /// @param autoDeleverageScale An admin configurable value which determines how much should the auto
    /// deleverage factor be.
    /// @param openInterestCapScale An admin configurable value which determines the market's open interest cap,
    /// according to the total delegated credit.
    /// @param skewCapScale An admin configurable value which determines the market's skew cap, according to the total
    /// delegated credit.
    /// @param realizedDebtUsd The net delta of USDz minted by the market and margin collateral collected from
    /// traders.
    /// @param inRangeVaults A heap of vaults that are actively delegating credit to this market.
    /// @param outRangeVaults A heap of vaults that have stopped delegating credit to this market.
    /// @param vaultsDebtDistribution `actor`: Vaults, `shares`: USD denominated credit delegated, `valuePerShare`:
    /// USD denominated debt per share.
    struct Data {
        uint256 marketId;
        uint256 autoDeleverageThreshold;
        uint256 autoDeleverageScale;
        uint256 openInterestCapScale;
        uint256 skewCapScale;
        int256 realizedDebtUsd;
        MinHeapLib.Heap inRangeVaults;
        MinHeapLib.Heap outRangeVaults;
        Distribution.Data vaultsDebtDistribution;
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

    /// @notice Computes the auto delevarage factor of the market according to its debt state and configured
    /// parameters.
    /// @return autoDeleverageFactor A decimal rate which determines how much should the market cut of the position's
    /// positive pnl. Goes from 0 to 1.
    function getAutoDeleverageFactor(Data storage self) internal view returns (UD60x18 autoDeleverageFactor) { }
}
