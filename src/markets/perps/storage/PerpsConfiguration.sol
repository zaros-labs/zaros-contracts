// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { Constants } from "@zaros/utils/Constants.sol";
import { IAggregatorV3 } from "@zaros/external/interfaces/chainlink/IAggregatorV3.sol";
import { IAccountNFT } from "@zaros/account-nft/interfaces/IAccountNFT.sol";

// Open Zeppelin dependencies
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

/// @title The PerpsConfiguration namespace.
library PerpsConfiguration {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;
    using SafeCast for int256;

    /// @notice Thrown when the provided `collateralType` is already enabled or disabled.
    error Zaros_PerpsConfiguration_InvalidCollateralConfig(address collateralType, bool shouldEnable);
    /// @notice Thrown when `collateralType` doesn't have a price feed defined to return its price.
    error Zaros_PerpsConfiguration_CollateralPriceFeedNotDefined(address collateralType);

    /// @dev PerpsConfiguration namespace storage slot.
    bytes32 internal constant SYSTEM_PERPS_MARKET_CONFIGURATION_SLOT =
        keccak256(abi.encode("fi.zaros.markets.PerpsConfiguration"));

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
        address chainlinkVerifier;
        address perpsAccountToken;
        address rewardDistributor;
        address usdToken;
        address zaros;
        uint96 nextAccountId;
        mapping(address => address) collateralPriceFeeds;
        EnumerableSet.AddressSet enabledCollateralTypes;
        EnumerableSet.UintSet enabledMarketsIds;
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
    /// @dev If the collateral is being enabled, the price feed must be set.
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

    /// @dev Helper called when a perps account is created.
    /// @return accountId The incremented account id of the new perps account.
    /// @return perpsAccountToken The perps account token contract.
    function onCreateAccount() internal returns (uint256 accountId, IAccountNFT perpsAccountToken) {
        Data storage self = load();
        accountId = ++self.nextAccountId;
        perpsAccountToken = IAccountNFT(self.perpsAccountToken);
    }
}
