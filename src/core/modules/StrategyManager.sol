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

// PRB Math dependencies
import { ud60x18 } from "@prb-math/UD60x18.sol";

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

    /// @dev TODO: add input checks, and needed collateral credit and zrsUSD debt accounting
    function mintZrsUsdToStrategy(address collateralType, uint256 amount) external override {
        Strategy.Data storage strategy = Strategy.load(collateralType);
        address strategyHandler = strategy.handler;
        if (msg.sender != strategyHandler) {
            revert Zaros_StrategyManagerModule_SenderNotStrategy(msg.sender, strategyHandler);
        }

        IZarosUSD zrsUsd = IZarosUSD(MarketManager.load().zrsUsd);
        zrsUsd.mint(strategyHandler, amount);

        emit LogMintZrsUsdToStrategy(collateralType, strategyHandler, amount);
    }

    /// @dev TODO: add needed collateral credit and zrsUSD debt accounting
    function depositToStrategy(
        address collateralType,
        uint256 amount,
        bytes calldata data
    )
        external
        override
        onlyOwner
    {
        Strategy.Data storage strategy = Strategy.load(collateralType);
        _requireStrategyIsRegistered(collateralType);

        IERC20(collateralType).approve(strategy.handler, amount);
        strategy.execute(amount, data);

        emit LogDepositToStrategy(msg.sender, collateralType, amount, data);
    }

    /// @dev TODO: add needed collateral credit and zrsUSD debt accounting
    function withdrawFromStrategy(
        address collateralType,
        uint256 amount,
        bytes calldata data
    )
        external
        override
        onlyOwner
    {
        Strategy.Data storage strategy = Strategy.load(collateralType);
        _requireStrategyIsRegistered(collateralType);

        strategy.withdraw(amount, data);

        emit LogWithdrawFromStrategy(msg.sender, collateralType, amount, data);
    }

    function _requireStrategyIsRegistered(address collateralType) private view {
        if (Strategy.load(collateralType).handler == address(0)) {
            revert Zaros_StrategyManagerModule_StrategyNotRegistered(collateralType);
        }
    }
}
