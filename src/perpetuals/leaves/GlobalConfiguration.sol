// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.25;

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
import { SD59x18 } from "@prb-math/SD59x18.sol";

/// @title The GlobalConfiguration namespace.
library GlobalConfiguration {
    using EnumerableSet for *;
    using SafeCast for int256;

    /// @dev GlobalConfiguration namespace storage slot.
    bytes32 internal constant GLOBAL_CONFIGURATION_SLOT =
        keccak256(abi.encode("fi.zaros.markets.GlobalConfiguration"));

    /// @notice {GlobalConfiguration} namespace storage structure.
    struct Data {
        uint128 maxPositionsPerAccount;
        uint128 marketOrderMaxLifetime;
        uint128 liquidationFeeUsdX18;
        address usdToken;
        address tradingAccountToken;
        uint96 nextAccountId;
        mapping(address => bool) isLiquidatorEnabled;
        EnumerableSet.AddressSet collateralLiquidationPriority;
        EnumerableSet.UintSet enabledMarketsIds;
        EnumerableSet.UintSet accountsIdsWithActivePositions;
    }

    /// @notice Loads the GlobalConfiguration entity.
    /// @return globalConfiguration The global configuration storage pointer.
    function load() internal pure returns (Data storage globalConfiguration) {
        bytes32 slot = GLOBAL_CONFIGURATION_SLOT;

        assembly {
            globalConfiguration.slot := slot
        }
    }

    /// @notice Reverts if the provided `marketId` is disabled.
    /// @param self The global configuration storage pointer.
    /// @param marketId The id of the market to check.
    function checkMarketIsEnabled(Data storage self, uint128 marketId) internal view {
        if (!self.enabledMarketsIds.contains(marketId)) {
            revert Errors.PerpMarketDisabled(marketId);
        }
    }

    /// @notice Adds a new perps market to the enabled markets set.
    /// @param self The global configuration storage pointer.
    /// @param marketId The id of the market to add.
    function addMarket(Data storage self, uint128 marketId) internal {
        bool added = self.enabledMarketsIds.add(uint256(marketId));

        if (!added) {
            revert Errors.PerpMarketAlreadyEnabled(marketId);
        }
    }

    /// @notice Removes a perps market from the enabled markets set.
    /// @param self The global configuration storage pointer.
    /// @param marketId The id of the market to add.
    function removeMarket(Data storage self, uint128 marketId) internal {
        bool added = self.enabledMarketsIds.remove(uint256(marketId));

        if (!added) {
            revert Errors.PerpMarketAlreadyDisabled(marketId);
        }
    }

    /// @notice Configures the collateral priority.
    /// @param self The global configuration storage pointer.
    /// @param collateralTypes The array of collateral type addresses.
    function configureCollateralLiquidationPriority(Data storage self, address[] memory collateralTypes) internal {
        for (uint256 i = 0; i < collateralTypes.length; i++) {
            self.collateralLiquidationPriority.add(collateralTypes[i]);
        }
    }

    /// @notice Removes the given collateral type from the collateral priority.
    /// @dev Reverts if the collateral type is not in the set.
    /// @param self The global configuration storage pointer.
    /// @param collateralType The address of the collateral type to remove.
    function removeCollateralFromLiquidationPriority(Data storage self, address collateralType) internal {
        bool removed = self.collateralLiquidationPriority.remove(collateralType);

        if (!removed) {
            revert Errors.MarginCollateralTypeNotInPriority(collateralType);
        }
    }
}
