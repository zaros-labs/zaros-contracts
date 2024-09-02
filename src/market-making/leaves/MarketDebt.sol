// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Distribution } from "./Distribution.sol";

// Open Zeppelin dependencies
import { EnumerableMap } from "@openzeppelin/utils/structs/EnumerableMap.sol";
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18 } from "@prb-math/SD59x18.sol";

/// @dev A perp market won't be abl
library MarketDebt {
    using Distribution for Distribution.Data;
    using EnumerableMap for EnumerableMap.AddressToUintMap;
    using EnumerableSet for EnumerableSet.UintSet;

    /// @notice ERC7201 storage location.
    bytes32 internal constant MARKET_DEBT_LOCATION =
        keccak256(abi.encode(uint256(keccak256("fi.zaros.market-making.MarketDebt")) - 1));

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
    /// traders and converted to USDC or ZLP Vaults assets.
    /// @param collectedMarginCollateral An enumerable map that stores the amount of each margin collateral asset
    /// collected from perps traders at a market.
    /// @param connectedVaultsIds The list of vaults ids delegating credit to this market. Whenever there's an update,
    /// a new `EnumerableSet.UintSet` is created.
    /// @param vaultsDebtDistribution `actor`: Vaults, `shares`: USD denominated credit delegated, `valuePerShare`:
    /// USD denominated debt per share.
    struct Data {
        uint128 marketId;
        uint128 autoDeleverageThreshold;
        uint128 autoDeleverageScale;
        uint128 openInterestCapScale;
        uint128 skewCapScale;
        int128 realizedDebtUsd;
        EnumerableMap.AddressToUintMap collectedMarginCollateral;
        EnumerableSet.UintSet[] connectedVaultsIds;
        Distribution.Data vaultsDebtDistribution;
    }

    /// @notice Loads a {MarketDebt} namespace.
    /// @param marketId The perp market id.
    /// @return marketDebt The loaded market debt storage pointer.
    function load(uint256 marketId) internal pure returns (Data storage marketDebt) {
        bytes32 slot = keccak256(abi.encode(MARKET_DEBT_LOCATION, marketId));
        assembly {
            marketDebt.slot := slot
        }
    }

    /// @notice Computes the auto delevarage factor of the market according to its debt state and configured
    /// parameters.
    /// @param self The market debt storage pointer.
    /// @return autoDeleverageFactor A decimal rate which determines how much should the market cut of the position's
    /// positive pnl. Goes from 0 to 1.
    function getAutoDeleverageFactor(Data storage self) internal view returns (UD60x18 autoDeleverageFactor) { }

    function getConnectedVaultsIds(Data storage self) internal view returns (uint256[] memory connectedVaultsIds) {
        if (self.connectedVaultsIds.length == 0) {
            return connectedVaultsIds;
        }

        connectedVaultsIds = self.connectedVaultsIds[self.connectedVaultsIds.length].values();
    }

    function getDelegatedCredit(Data storage self) internal view returns (UD60x18 totalDelegatedCredit) {
        return ud60x18(self.vaultsDebtDistribution.totalShares);
    }

    function getInRangeVaultsIds(Data storage self) internal returns (uint128[] memory inRangeVaultsIds) { }

    function getMarketCaps(Data storage self)
        internal
        view
        returns (UD60x18 openInterestCapX18, UD60x18 skewCapX18)
    {
        UD60x18 totalDelegatedCredit = ud60x18(self.vaultsDebtDistribution.totalShares);

        openInterestCapX18 = ud60x18(self.openInterestCapScale).mul(totalDelegatedCredit);
        skewCapX18 = ud60x18(self.skewCapScale).mul(totalDelegatedCredit);
    }

    function getTotalDebt(Data storage self) internal view returns (SD59x18 totalDebtUsdX18) { }

    function addMarginCollateral(Data storage self, address collateralType, UD60x18 amountX18) internal { }

    function distributeDebtToVaults(
        Data storage self,
        SD59x18 newTotalDebtUsdX18,
        SD59x18 realizedDebtUsdX18
    )
        internal
        returns (SD59x18 realizedDebtChangeUsdX18)
    { }
}
