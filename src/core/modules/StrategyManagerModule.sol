// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { IStrategy } from "@zaros/strategies/interfaces/IStrategy.sol";
import { IZarosUSD } from "@zaros/usd/interfaces/IZarosUSD.sol";
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

    bytes32 private constant _STRATEGY_FEATURE_FLAG = "registerStrategy";

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
        if (msg.sender != strategyHandler && msg.sender != owner()) {
            revert Zaros_StrategyManagerModule_InvalidSender(msg.sender, strategyHandler);
        }

        IZarosUSD zrsUsd = IZarosUSD(MarketManager.load().zrsUsd);
        zrsUsd.mint(strategyHandler, amount);

        emit LogMintZrsUsdToStrategy(collateralType, strategyHandler, amount);
    }

    /// @dev TODO: add needed collateral credit and zrsUSD debt accounting
    function depositToStrategy(
        address collateralType,
        uint256 assetsAmount,
        uint256 minSharesAmount
    )
        external
        override
        onlyOwner
    {
        Strategy.Data storage strategy = Strategy.load(collateralType);
        _requireStrategyIsRegistered(collateralType);

        uint256 sharesAmount = IStrategy(strategy.handler).previewDeposit(assetsAmount);
        _requireEnoughOutput(sharesAmount, minSharesAmount);

        IERC20(collateralType).approve(strategy.handler, assetsAmount);
        IStrategy(strategy.handler).deposit(assetsAmount, address(this));

        emit LogDepositToStrategy(msg.sender, collateralType, assetsAmount);
    }

    /// @dev TODO: add needed collateral credit and zrsUSD debt accounting
    function withdrawFromStrategy(
        address collateralType,
        uint256 sharesAmount,
        uint256 minAssetsAmount
    )
        external
        override
        onlyOwner
    {
        Strategy.Data storage strategy = Strategy.load(collateralType);
        IStrategy strategyContract = IStrategy(strategy.handler);
        _requireStrategyIsRegistered(collateralType);

        uint256 assetsAmount = strategyContract.previewWithdraw(sharesAmount);
        _requireEnoughOutput(assetsAmount, minAssetsAmount);

        strategyContract.withdraw(assetsAmount, address(this), address(this));

        emit LogWithdrawFromStrategy(msg.sender, collateralType, sharesAmount);
    }

    function _requireStrategyIsRegistered(address collateralType) private view {
        if (Strategy.load(collateralType).handler == address(0)) {
            revert Zaros_StrategyManagerModule_StrategyNotRegistered(collateralType);
        }
    }

    function _requireEnoughOutput(uint256 amount, uint256 minAmount) private pure {
        if (amount < minAmount) {
            revert Zaros_StrategyManagerModule_OutputTooLow(amount, minAmount);
        }
    }
}
