// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { Constants } from "@zaros/utils/Constants.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { IAggregatorV3 } from "@zaros/external/chainlink/interfaces/IAggregatorV3.sol";
import { IAccountNFT } from "@zaros/account-nft/interfaces/IAccountNFT.sol";

// Open Zeppelin dependencies
import { EnumerableMap } from "@openzeppelin/utils/structs/EnumerableMap.sol";
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

/// @title The GlobalConfiguration namespace.
library GlobalConfiguration {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;
    using SafeCast for int256;

    /// @dev GlobalConfiguration namespace storage slot.
    bytes32 internal constant PERPS_CONFIGURATION_SLOT = keccak256(abi.encode("fi.zaros.markets.GlobalConfiguration"));

    /// @notice {PerpConfiguration} namespace storage structure.
    struct Data {
        uint128 maxPositionsPerAccount;
        uint128 marketOrderMaxLifetime;
        address rewardDistributor;
        address usdToken;
        address liquidityEngine;
        address perpsAccountToken;
        uint96 nextAccountId;
        EnumerableSet.UintSet enabledMarketsIds;
    }

    /// @notice Loads the GlobalConfiguration entity.
    /// @return globalConfiguration The perps configuration storage pointer.
    function load() internal pure returns (Data storage globalConfiguration) {
        bytes32 slot = PERPS_CONFIGURATION_SLOT;

        assembly {
            globalConfiguration.slot := slot
        }
    }

    /// @notice Adds a new perps market to the enabled markets set.
    /// @param self The perps configuration storage pointer.
    /// @param marketId The id of the market to add.
    function addMarket(Data storage self, uint128 marketId) internal {
        bool added = self.enabledMarketsIds.add(uint256(marketId));

        if (!added) {
            revert Errors.PerpMarketAlreadyEnabled(marketId);
        }
    }

    /// @notice Removes a perps market from the enabled markets set.
    /// @param self The perps configuration storage pointer.
    /// @param marketId The id of the market to add.
    function removeMarket(Data storage self, uint128 marketId) internal {
        bool added = self.enabledMarketsIds.remove(uint256(marketId));

        if (!added) {
            revert Errors.PerpMarketAlreadyDisabled(marketId);
        }
    }

    /// @notice Reverts if the provided `marketId` is disabled.
    /// @param self The perps configuration storage pointer.
    /// @param marketId The id of the market to check.
    function checkMarketIsEnabled(Data storage self, uint128 marketId) internal view {
        if (!self.enabledMarketsIds.contains(marketId)) {
            revert Errors.PerpMarketDisabled(marketId);
        }
    }
}
