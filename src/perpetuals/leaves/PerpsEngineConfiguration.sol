// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";

// Open Zeppelin dependencies
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

/// @title The PerpsEngineConfiguration namespace.
library PerpsEngineConfiguration {
    using EnumerableSet for *;
    using SafeCast for int256;

    /// @notice ERC7201 storage location.
    bytes32 internal constant PERPS_ENGINE_CONFIGURATION_LOCATION = keccak256(
        abi.encode(uint256(keccak256("fi.zaros.perpetuals.PerpsEngineConfiguration")) - 1)
    ) & ~bytes32(uint256(0xff));

    /// @notice {PerpsEngineConfiguration} namespace storage structure.
    /// @param maxPositionsPerAccount The maximum amount of active positions a trading account may have.
    /// @param marketOrderMinLifetime The minimum amount of time an active market order needs to be canceled.
    /// @param liquidationFeeUsdX18 The liquidation fee charged in USD.
    /// @param nextAccountId The next available trading account id.
    /// @param usdToken The address of the USD token (USD Token).
    /// @param tradingAccountToken The address of the trading account NFT.
    /// @param referralModule The address of the referral module.
    /// @param whitelist The address of the whitelist.
    /// @param maxVerificationDelay The maximum delay allowed for the off chain price verification.
    /// @param isLiquidatorEnabled The mapping of liquidator addresses to their enabled status.
    /// @param collateralLiquidationPriority The set of collateral types in order of liquidation priority.
    /// @param enabledMarketsIds The set of enabled perp markets.
    /// @param accountsIdsWithActivePositions The set of trading account ids with active positions
    struct Data {
        uint128 maxPositionsPerAccount;
        uint128 marketOrderMinLifetime;
        uint128 liquidationFeeUsdX18;
        uint96 nextAccountId;
        // TODO: We may need to update the two following recipients
        // to call functions from the MM engine.
        address marketMakingEngine;
        address usdToken;
        address tradingAccountToken;
        address referralModule;
        address whitelist;
        uint256 maxVerificationDelay;
        mapping(address => bool) isLiquidatorEnabled;
        EnumerableSet.AddressSet collateralLiquidationPriority;
        EnumerableSet.UintSet enabledMarketsIds;
        EnumerableSet.UintSet accountsIdsWithActivePositions;
    }

    /// @notice Loads the {PerpsEngineConfiguration}.
    /// @return perpsEngineConfiguration The perps engine configuration storage pointer.
    function load() internal pure returns (Data storage perpsEngineConfiguration) {
        bytes32 slot = PERPS_ENGINE_CONFIGURATION_LOCATION;

        assembly {
            perpsEngineConfiguration.slot := slot
        }
    }

    /// @notice Reverts if the provided `marketId` is disabled.
    /// @param self The perps engine configuration storage pointer.
    /// @param marketId The id of the market to check.
    function checkMarketIsEnabled(Data storage self, uint128 marketId) internal view {
        if (!self.enabledMarketsIds.contains(marketId)) {
            revert Errors.PerpMarketDisabled(marketId);
        }
    }

    /// @notice Adds a new perps market to the enabled markets set.
    /// @param self The perps engine configuration storage pointer.
    /// @param marketId The id of the market to add.
    function addMarket(Data storage self, uint128 marketId) internal {
        bool added = self.enabledMarketsIds.add(uint256(marketId));

        if (!added) {
            revert Errors.PerpMarketAlreadyEnabled(marketId);
        }
    }

    /// @notice Removes a perps market from the enabled markets set.
    /// @param self The perps engine configuration storage pointer.
    /// @param marketId The id of the market to add.
    function removeMarket(Data storage self, uint128 marketId) internal {
        bool removed = self.enabledMarketsIds.remove(uint256(marketId));

        if (!removed) {
            revert Errors.PerpMarketAlreadyDisabled(marketId);
        }
    }

    /// @notice Configures the collateral priority.
    /// @param self The perps engine configuration storage pointer.
    /// @param collateralTypes The array of collateral type addresses.
    function configureCollateralLiquidationPriority(Data storage self, address[] memory collateralTypes) internal {
        uint256 cachedCollateralTypesCached = collateralTypes.length;

        for (uint256 i; i < cachedCollateralTypesCached; i++) {
            if (collateralTypes[i] == address(0)) {
                revert Errors.ZeroInput("collateralType");
            }

            if (!self.collateralLiquidationPriority.add(collateralTypes[i])) {
                revert Errors.MarginCollateralAlreadyInPriority(collateralTypes[i]);
            }
        }
    }

    /// @notice Removes the given collateral type from the collateral priority.
    /// @dev Reverts if the collateral type is not in the set.
    /// @param self The perps engine configuration storage pointer.
    /// @param collateralType The address of the collateral type to remove.
    function removeCollateralFromLiquidationPriority(Data storage self, address collateralType) internal {
        // does the collateral being removed exist?
        bool isInCollateralLiquidationPriority = self.collateralLiquidationPriority.contains(collateralType);

        // if not, revert
        if (!isInCollateralLiquidationPriority) revert Errors.MarginCollateralTypeNotInPriority(collateralType);

        // the following code is required since EnumerableSet::remove
        // uses the swap-and-pop technique which corrupts the order

        // copy the existing collateral order
        address[] memory copyCollateralLiquidationPriority = self.collateralLiquidationPriority.values();

        // cache length
        uint256 copyCollateralLiquidationPriorityLength = copyCollateralLiquidationPriority.length;

        // create a new array to store the new order
        address[] memory newCollateralLiquidationPriority = new address[](copyCollateralLiquidationPriorityLength - 1);

        uint256 indexCollateral;

        // iterate over the in-memory copies
        for (uint256 i; i < copyCollateralLiquidationPriorityLength; i++) {
            // fetch current collateral
            address collateral = copyCollateralLiquidationPriority[i];

            // remove current collateral from storage set
            self.collateralLiquidationPriority.remove(collateral);

            // if the current collateral is the one we want to remove, skip
            // to the next loop iteration
            if (collateral == collateralType) {
                continue;
            }

            // otherwise add current collateral to the new in-memory
            // order we are building
            newCollateralLiquidationPriority[indexCollateral] = collateral;
            indexCollateral++;
        }

        // the collateral priority in storage has been emptied and the new
        // order has been built in memory, so iterate through the new order
        // and add it to storage
        for (uint256 i; i < copyCollateralLiquidationPriorityLength - 1; i++) {
            self.collateralLiquidationPriority.add(newCollateralLiquidationPriority[i]);
        }
    }
}
