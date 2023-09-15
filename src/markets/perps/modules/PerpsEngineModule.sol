// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { IPerpsEngine } from "../interfaces/IPerpsEngine.sol";
import { OrderFees } from "../storage/OrderFees.sol";
import { Position } from "../storage/Position.sol";
import { PerpsMarket } from "../storage/PerpsMarket.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18 } from "@prb-math/SD59x18.sol";

contract PerpsEngineModule is IPerpsEngine {
    using PerpsMarket for PerpsMarket.Data;
    using Position for Position.Data;

    // constructor(
    //     string memory _name,
    //     string memory _symbol,
    //     address _oracle,
    //     address _perpsExchange,
    //     uint256 _maxLeverage,
    //     OrderFees.Data memory _orderFees
    // ) {
    //     PerpsMarket.Data storage perpsMarket = PerpsMarket.load();
    //     perpsMarket.name = _name;
    //     perpsMarket.symbol = _symbol;
    //     perpsMarket.oracle = _oracle;
    //     perpsMarket.perpsExchange = _perpsExchange;
    //     perpsMarket.maxLeverage = _maxLeverage;
    //     perpsMarket.orderFees = _orderFees;
    // }

    function name() external view returns (string memory) {
        return PerpsMarket.load().name;
    }

    function symbol() external view returns (string memory) {
        return PerpsMarket.load().symbol;
    }

    function skew() external view returns (SD59x18) {
        return sd59x18(PerpsMarket.load().skew);
    }

    function totalOpenInterest() external view returns (UD60x18) {
        return ud60x18(PerpsMarket.load().size);
    }

    function indexPrice() external view returns (UD60x18) {
        PerpsMarket.Data storage perpsMarket = PerpsMarket.load();

        return perpsMarket.getIndexPrice();
    }

    function oracle() external view returns (address) {
        return PerpsMarket.load().oracle;
    }

    function fundingRate() external view returns (SD59x18) {
        return sd59x18(0);
    }

    function fundingVelocity() external view returns (SD59x18) {
        return sd59x18(0);
    }

    function getOpenPositionData(uint256 accountId)
        external
        view
        returns (
            UD60x18 notionalValue,
            SD59x18 size,
            SD59x18 pnl,
            SD59x18 accruedFunding,
            SD59x18 netFundingPerUnit,
            SD59x18 nextFunding
        )
    {
        PerpsMarket.Data storage perpsMarket = PerpsMarket.load();
        Position.Data storage position = perpsMarket.positions[accountId];
        UD60x18 price = perpsMarket.getIndexPrice();

        (notionalValue, size, pnl, accruedFunding, netFundingPerUnit, nextFunding) = position.getPositionData(price);
    }

    function setPerpsExchange(address perpsExchange) external {
        PerpsMarket.load().perpsExchange = perpsExchange;
    }
}
