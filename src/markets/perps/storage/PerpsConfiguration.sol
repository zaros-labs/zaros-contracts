// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { IAccountNFT } from "@zaros/account-nft/interfaces/IAccountNFT.sol";

// Open Zeppelin dependencies
// import { EnumerableMap } from "@openzeppelin/utils/structs/EnumerableMap.sol";
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

/// @title The PerpsConfiguration namespace.
library PerpsConfiguration {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;

    /// @notice Thrown when the provided `collateralType` is already enabled or disabled.
    error Zaros_PerpsConfiguration_InvalidCollateralConfig(address collateralType, bool shouldEnable);

    /// @dev PerpsConfiguration namespace storage slot.
    bytes32 internal constant SYSTEM_PERPS_MARKET_CONFIGURATION_SLOT =
        keccak256(abi.encode("fi.zaros.markets.PerpsConfiguration"));

    /// @notice {PerpConfiguration} namespace storage structure.
    /// @param enabledCollateralTypes The cross margin supported collateral types.
    /// @param enabledMarketsIds The enabled perps markets ids.
    /// @param zaros The Zaros protocol contract address.
    /// @param rewardDistributor The reward distributor contract address.
    /// @param perpsAccountToken The perps account token contract address.
    /// @param nextAccountId The next account id to be used.
    struct Data {
        EnumerableSet.AddressSet enabledCollateralTypes;
        EnumerableSet.UintSet enabledMarketsIds;
        address zaros;
        address rewardDistributor;
        address perpsAccountToken;
        uint96 nextAccountId;
    }

    /// @dev Loads the PerpsConfiguration entity.
    /// @return perpsConfiguration The perps configuration storage pointer.
    function load() internal pure returns (Data storage perpsConfiguration) {
        bytes32 slot = SYSTEM_PERPS_MARKET_CONFIGURATION_SLOT;

        assembly {
            perpsConfiguration.slot := slot
        }
    }

    /// @dev Returns whether the given collateral type is enabled.
    /// @param self The perps configuration storage pointer.
    /// @param collateralType The address of the collateral type.
    /// @return enabled `true` if the collateral type is enabled, `false` otherwise.
    function isCollateralEnabled(Data storage self, address collateralType) internal view returns (bool) {
        return self.enabledCollateralTypes.contains(collateralType);
    }

    /// @dev Enables or disables a collateral type to be used as margin. If the given configuration
    /// is already set, the function reverts.
    /// @param self The perps configuration storage pointer.
    /// @param collateralType The address of the collateral type.
    /// @param shouldEnable `true` if the collateral type should be enabled, `false` if it should be disabled.
    function setIsCollateralEnabled(Data storage self, address collateralType, bool shouldEnable) internal {
        bool success;
        if (shouldEnable) {
            success = self.enabledCollateralTypes.add(collateralType);
        } else {
            success = self.enabledCollateralTypes.remove(collateralType);
        }

        if (!success) {
            revert Zaros_PerpsConfiguration_InvalidCollateralConfig(collateralType, shouldEnable);
        }
    }

    /// @dev Adds a new perps market to the enabled markets set.
    /// @param self The perps configuration storage pointer.
    /// @param marketId The id of the market to add.
    function addMarket(Data storage self, uint128 marketId) internal {
        self.enabledMarketsIds.add(uint256(marketId));
    }

    /// @dev Helper called when a perps account is created.
    /// @return accountId The incremented account id of the new perps account.
    /// @return perpsAccountToken The perps account token contract.
    function onCreateAccount() internal returns (uint256 accountId, IAccountNFT perpsAccountToken) {
        Data storage self = load();
        accountId = ++self.nextAccountId;
        perpsAccountToken = IAccountNFT(self.perpsAccountToken);
    }
}
