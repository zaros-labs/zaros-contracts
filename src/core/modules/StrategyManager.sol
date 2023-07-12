// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { IZarosUSD } from "../../usd/interfaces/IZarosUSD.sol";

import { IStrategyManagerModule } from "../interfaces/IStrategyManagerModule.sol";
import { MarketManager } from "../storage/MarketManager.sol";
import { Strategy } from "../storage/Strategy.sol";

// Open Zeppelin dependencies
import { Ownable } from "@openzeppelin/access/Ownable.sol";
import { IERC20, SafeERC20 } from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";

contract StrategyManagerModule is IStrategyManagerModule, Ownable {
    using SafeERC20 for IZarosUSD;
    using MarketManager for MarketManager.Data;
    using Strategy for Strategy.Data;

    function getStrategy(address collateralType) external view override returns (address strategy) {
        return Strategy.load(collateralType).handler;
    }

    function registerStrategy(address collateralType, address strategy) external override onlyOwner {
        Strategy.create(collateralType, strategy);

        emit LogRegisterStrategy(collateralType, strategy);
    }

    function mintZrsUsdToStrategy(address collateralType, uint256 amount) external override onlyOwner {
        Strategy.Data storage strategy = Strategy.load(collateralType);
        IZarosUSD zrsUsd = IZarosUSD(MarketManager.load().zrsUsd);
        zrsUsd.mint(strategy.handler, amount);
    }

    function depositToStrategy(
        address collateralType,
        uint256 amount,
        bytes calldata data
    )
        external
        override
        onlyOwner
    { }

    function withdrawFromStrategy(
        address collateralType,
        uint256 amount,
        bytes calldata data
    )
        external
        override
        onlyOwner
    { }
}
