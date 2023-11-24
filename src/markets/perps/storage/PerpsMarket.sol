// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { IAggregatorV3 } from "@zaros/external/chainlink/interfaces/IAggregatorV3.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { OracleUtil } from "@zaros/utils/OracleUtil.sol";
import { Order } from "./Order.sol";
import { OrderFees } from "./OrderFees.sol";
import { Position } from "./Position.sol";
import { SettlementStrategy } from "./SettlementStrategy.sol";

// Open Zeppelin dependencies
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18 } from "@prb-math/SD59x18.sol";

/// @title The PerpsMarket namespace.
library PerpsMarket {
    /// @dev Constant base domain used to access a given PerpsMarket's storage slot.
    string internal constant PERPS_MARKET_DOMAIN = "fi.liquidityEngine.markets.PerpsMarket";

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
        SettlementStrategy.Data settlementStrategy;
        mapping(uint256 accountId => Position.Data) positions;
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
        uint128 maintenanceMarginRate,
        uint128 maxOpenInterest,
        uint128 minInitialMarginRate,
        SettlementStrategy.Data memory settlementStrategy,
        OrderFees.Data memory orderFees
    )
        internal
    {
        Data storage self = load(marketId);
        if (self.id != 0) {
            revert Errors.MarketAlreadyExists(marketId, msg.sender);
        }

        // TODO: remember to test gas cost / number of sstores here
        self.id = marketId;
        self.name = name;
        self.symbol = symbol;
        self.priceFeed = priceFeed;
        self.maintenanceMarginRate = maintenanceMarginRate;
        self.maxOpenInterest = maxOpenInterest;
        self.minInitialMarginRate = minInitialMarginRate;
        self.settlementStrategy = settlementStrategy;
        self.orderFees = orderFees;
    }

    /// @notice TODO: Call the OracleManager
    function getIndexPrice(Data storage self) internal view returns (UD60x18 price) {
        price = OracleUtil.getPrice(IAggregatorV3(self.priceFeed));
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
}
