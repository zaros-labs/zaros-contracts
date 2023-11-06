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

    /// @notice Thrown when `collateralType` doesn't have a price feed defined to return its price.
    error Zaros_PerpsConfiguration_CollateralPriceFeedNotDefined(address collateralType);

    /// @dev PerpsConfiguration namespace storage slot.
    bytes32 internal constant PERPS_CONFIGURATION_SLOT = keccak256(abi.encode("fi.zaros.markets.PerpsConfiguration"));

    /// @notice {PerpConfiguration} namespace storage structure.
    /// @param rewardDistributor The reward distributor contract address.
    /// @param perpsAccountToken The perps account token contract address.
    /// @param zaros The Zaros protocol contract address.
    /// @param nextAccountId The next account id to be used.
    /// @param enabledCollateralTypes The cross margin supported collateral types.
    /// @param enabledMarketsIds The enabled perps markets ids.
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
        mapping(address => address) collateralPriceFeeds;
        mapping(address => uint256) collateralCaps;
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

    /// @dev Returns the maximum amount that can be deposited as margin for a given
    /// collateral type.
    /// @param self The perps configuration storage pointer.
    /// @param collateralType The address of the collateral type.
    /// @return depositCap The configured deposit cap for the given collateral type.
    function getDepositCapForCollateralType(
        Data storage self,
        address collateralType
    )
        internal
        view
        returns (UD60x18 depositCap)
    {
        depositCap = ud60x18(self.collateralCaps[collateralType]);
    }

    /// @dev Updates the deposit cap of a given collateral type. If zero, it is considered
    /// disabled.
    /// @dev If the collateral is enabled, a price feed must be set.
    /// @param self The perps configuration storage pointer.
    /// @param collateralType The address of the collateral type.
    /// @param depositCap The maximum amount of collateral that can be deposited.
    function configureCollateral(Data storage self, address collateralType, UD60x18 depositCap) internal {
        self.collateralCaps[collateralType] = depositCap.intoUint256();
    }

    function configurePriceFeed(Data storage self, address collateralType, address priceFeed) internal {
        self.collateralPriceFeeds[collateralType] = priceFeed;
    }

    function getCollateralPrice(Data storage self, address collateralType) internal view returns (UD60x18) {
        address priceFeed = self.collateralPriceFeeds[collateralType];
        if (priceFeed == address(0)) {
            revert Zaros_PerpsConfiguration_CollateralPriceFeedNotDefined(collateralType);
        }

        return getPrice(self, IAggregatorV3(priceFeed));
    }

    function getPrice(Data storage self, IAggregatorV3 priceFeed) internal view returns (UD60x18 price) {
        uint8 decimals = priceFeed.decimals();
        (, int256 answer,,,) = priceFeed.latestRoundData();

        // should panic if decimals > 18
        assert(decimals <= Constants.DECIMALS);
        price = ud60x18(answer.toUint256() * 10 ** (Constants.DECIMALS - decimals));
    }

    /// @dev Adds a new perps market to the enabled markets set.
    /// @param self The perps configuration storage pointer.
    /// @param marketId The id of the market to add.
    function addMarket(Data storage self, uint128 marketId) internal {
        self.enabledMarketsIds.add(uint256(marketId));
    }
}
