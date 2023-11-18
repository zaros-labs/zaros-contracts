// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { Constants } from "@zaros/utils/Constants.sol";
import { IAggregatorV3 } from "@zaros/external/interfaces/chainlink/IAggregatorV3.sol";
import { IAccountNFT } from "@zaros/account-nft/interfaces/IAccountNFT.sol";

// Open Zeppelin dependencies
import { EnumerableMap } from "@openzeppelin/utils/structs/EnumerableMap.sol";
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

/// @title The PerpsConfiguration namespace.
library PerpsConfiguration {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;
    using SafeCast for int256;

    /// @dev PerpsConfiguration namespace storage slot.
    bytes32 internal constant PERPS_CONFIGURATION_SLOT = keccak256(abi.encode("fi.zaros.markets.PerpsConfiguration"));

    /// @notice {PerpConfiguration} namespace storage structure.
    struct Data {
        uint256 maxPositionsPerAccount;
        uint256 maxActiveOrders;
        address chainlinkForwarder;
        address chainlinkVerifier;
        address rewardDistributor;
        address usdToken;
        address zaros;
        address perpsAccountToken;
        uint96 nextAccountId;
        EnumerableSet.UintSet enabledMarketsIds;
    }

    /// @dev Loads the PerpsConfiguration entity.
    /// @return perpsConfiguration The perps configuration storage pointer.
    function load() internal pure returns (Data storage perpsConfiguration) {
        bytes32 slot = PERPS_CONFIGURATION_SLOT;

        assembly {
            perpsConfiguration.slot := slot
        }
    }

    /// @dev Adds a new perps market to the enabled markets set.
    /// @param self The perps configuration storage pointer.
    /// @param marketId The id of the market to add.
    function addMarket(Data storage self, uint128 marketId) internal {
        self.enabledMarketsIds.add(uint256(marketId));
    }
}
