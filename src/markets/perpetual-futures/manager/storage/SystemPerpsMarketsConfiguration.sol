// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { IAccountNFT } from "@zaros/account-nft/interfaces/IAccountNFT.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

// Open Zeppelin dependencies
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";

library SystemPerpsMarketsConfiguration {
    using EnumerableSet for EnumerableSet.AddressSet;

    error Zaros_SystemPerpsMarketsConfiguration_InvalidToggle(address collateralType, bool shouldEnable);

    bytes32 internal constant SYSTEM_PERPS_MARKET_CONFIGURATION_SLOT =
        keccak256(abi.encode("fi.zaros.markets.SystemPerpsMarketsConfiguration"));

    struct Data {
        EnumerableSet.AddressSet enabledCollateralTypes;
        address zaros;
        address rewardDistributor;
        address accountToken;
        uint96 nextAccountId;
    }

    function load() internal pure returns (Data storage systemPerpsMarketsConfiguration) {
        bytes32 slot = SYSTEM_PERPS_MARKET_CONFIGURATION_SLOT;
        assembly {
            systemPerpsMarketsConfiguration.slot := slot
        }
    }

    function isCollateralEnabled(Data storage self, address collateralType) internal view returns (bool) {
        return self.enabledCollateralTypes.contains(collateralType);
    }

    /// @dev If collateralType is already enabled or disabled, this function won't revert.
    function setIsCollateralEnabled(Data storage self, address collateralType, bool shouldEnable) internal {
        bool success;
        if (shouldEnable) {
            success = self.enabledCollateralTypes.add(collateralType);
        } else {
            success = self.enabledCollateralTypes.remove(collateralType);
        }

        if (!success) {
            revert Zaros_SystemPerpsMarketsConfiguration_InvalidToggle(collateralType, shouldEnable);
        }
    }

    function onCreateAccount() internal returns (uint128 accountId, IAccountNFT accountTokenModule) {
        Data storage self = load();
        accountId = ++self.nextAccountId;
        accountTokenModule = IAccountNFT(self.accountToken);
    }
}
