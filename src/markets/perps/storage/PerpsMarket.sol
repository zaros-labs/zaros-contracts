// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { Constants } from "@zaros/utils/Constants.sol";
import { IAggregatorV3 } from "@zaros/external/interfaces/chainlink/IAggregatorV3.sol";
import { Order } from "../storage/Order.sol";
import { OrderFees } from "../storage/OrderFees.sol";
import { Position } from "../storage/Position.sol";

// Open Zeppelin dependencies
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18 } from "@prb-math/SD59x18.sol";

/// @title The PerpsMarket namespace.
library PerpsMarket {
    using EnumerableSet for EnumerableSet.UintSet;
    using SafeCast for int256;

    /// @notice Thrown when a perps market id has already been used.
    error Zaros_PerpsMarket_MarketAlreadyExists(uint128 marketId, address sender);

    /// @dev Constant base domain used to access a given PerpsMarket's storage slot.
    string internal constant PERPS_MARKET_DOMAIN = "fi.zaros.markets.PerpsMarket";

    struct Data {
        string name;
        string symbol;
        uint128 id;
        uint128 minInitialMarginRate;
        uint128 maintenanceMarginRate;
        uint128 maxOpenInterest;
        int128 skew;
        uint128 size;
        address priceFeed;
        OrderFees.Data orderFees;
        mapping(uint256 accountId => Position.Data) positions;
        mapping(uint256 accountId => EnumerableSet.UintSet) activeOrdersIds;
        mapping(uint256 accountId => Order.Data[]) orders;
    }

    /// @dev TODO: add function that only loads a valid / existing perps market
    function load(uint128 marketId) internal pure returns (Data storage perpsMarket) {
        bytes32 slot = keccak256(abi.encode(PERPS_MARKET_DOMAIN, marketId));
        assembly {
            perpsMarket.slot := slot
        }
    }

    function create(
        uint128 marketId,
        string memory name,
        string memory symbol,
        address priceFeed,
        uint128 minInitialMarginRate,
        uint128 maxOpenInterest,
        OrderFees.Data memory orderFees
    )
        internal
    {
        Data storage perpsMarket = load(marketId);
        if (perpsMarket.id != 0) {
            revert Zaros_PerpsMarket_MarketAlreadyExists(marketId, msg.sender);
        }

        // TODO: remember to test gas cost / number of sstores here
        perpsMarket.id = marketId;
        perpsMarket.name = name;
        perpsMarket.symbol = symbol;
        perpsMarket.priceFeed = priceFeed;
        perpsMarket.minInitialMarginRate = minInitialMarginRate;
        perpsMarket.maxOpenInterest = maxOpenInterest;
        perpsMarket.orderFees = orderFees;
    }

    /// @dev TODO: improve this
    function getIndexPrice(Data storage self) internal view returns (UD60x18) {
        IAggregatorV3 priceFeed = IAggregatorV3(self.priceFeed);
        uint8 decimals = priceFeed.decimals();
        (, int256 answer,,,) = priceFeed.latestRoundData();

        // should panic if decimals > 18
        assert(decimals <= Constants.DECIMALS);
        UD60x18 price = ud60x18(answer.toUint256() * 10 ** (Constants.DECIMALS - decimals));

        return price;
    }

    function getCurrentFundingRate(Data storage self) internal view returns (SD59x18) {
        return sd59x18(0);
    }

    function getCurrentFundingVelocity(Data storage self) internal view returns (SD59x18) {
        return sd59x18(0);
    }

    function calculateNextFundingFeePerUnit(Data storage self, UD60x18 price) internal view returns (SD59x18) {
        return sd59x18(0);
    }

    function isOrderActive(Data storage self, uint256 accountId, uint8 orderId) internal view returns (bool) {
        return self.activeOrdersIds[accountId].contains(orderId);
    }

    function updateAccountActiveOrders(Data storage self, uint256 accountId, uint8 orderId, bool isActive) internal {
        if (isActive) {
            self.activeOrdersIds[accountId].add(orderId);
        } else {
            self.activeOrdersIds[accountId].remove(orderId);
        }
    }
}
