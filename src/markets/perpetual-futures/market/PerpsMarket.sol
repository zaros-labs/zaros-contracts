// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { IPerpsMarket } from "./interfaces/IPerpsMarket.sol";
import { OrderModule } from "./modules/OrderModule.sol";
import { OrderFees } from "./storage/OrderFees.sol";
import { Position } from "./storage/Position.sol";
import { PerpsMarketConfig } from "./storage/PerpsMarketConfig.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18 } from "@prb-math/SD59x18.sol";

contract PerpsMarket is IPerpsMarket, OrderModule {
    using PerpsMarketConfig for PerpsMarketConfig.Data;

    constructor(
        string memory _name,
        string memory _symbol,
        address _oracle,
        address _perpsVault,
        uint256 _maxLeverage,
        OrderFees.Data memory _orderFees
    ) {
        PerpsMarketConfig.Data storage perpsMarketConfig = PerpsMarketConfig.load();
        perpsMarketConfig.name = _name;
        perpsMarketConfig.symbol = _symbol;
        perpsMarketConfig.oracle = _oracle;
        perpsMarketConfig.perpsVault = _perpsVault;
        perpsMarketConfig.maxLeverage = _maxLeverage;
        perpsMarketConfig.orderFees = _orderFees;
    }

    function name() external view returns (string memory) {
        return PerpsMarketConfig.load().name;
    }

    function symbol() external view returns (string memory) {
        return PerpsMarketConfig.load().symbol;
    }

    function skew() external view returns (SD59x18) {
        return sd59x18(PerpsMarketConfig.load().skew);
    }

    function size() external view returns (UD60x18) {
        return ud60x18(PerpsMarketConfig.load().size);
    }

    function indexPrice() external view returns (UD60x18) {
        PerpsMarketConfig.Data storage perpsMarketConfig = PerpsMarketConfig.load();

        return perpsMarketConfig.getIndexPrice();
    }

    function oracle() external view returns (address) {
        return PerpsMarketConfig.load().oracle;
    }

    function fundingRate() external view returns (SD59x18) {
        return sd59x18(0);
    }

    function fundingVelocity() external view returns (SD59x18) {
        return sd59x18(0);
    }

    function getOpenPosition(address account) external view returns (Position.Data memory) {
        PerpsMarketConfig.Data storage perpsMarketConfig = PerpsMarketConfig.load();
        Position.Data memory position = perpsMarketConfig.positions[account];

        return position;
    }

    function setPerpsVault(address perpsVault) external {
        PerpsMarketConfig.load().perpsVault = perpsVault;
    }
}
