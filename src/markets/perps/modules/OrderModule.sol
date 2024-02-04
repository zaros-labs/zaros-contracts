// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { ISettlementStrategy } from "@zaros/markets/settlement/interfaces/ISettlementStrategy.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { IOrderModule } from "../interfaces/IOrderModule.sol";
import { MarketOrder } from "../storage/MarketOrder.sol";
import { OrderFees } from "../storage/OrderFees.sol";
import { PerpsAccount } from "../storage/PerpsAccount.sol";
import { GlobalConfiguration } from "../storage/GlobalConfiguration.sol";
import { PerpMarket } from "../storage/PerpMarket.sol";
import { Position } from "../storage/Position.sol";
import { SettlementConfiguration } from "../storage/SettlementConfiguration.sol";

// Open Zeppelin dependencies
import { IERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";
import { SafeERC20 } from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18, ZERO as SD_ZERO, unary } from "@prb-math/SD59x18.sol";

contract OrderModule is IOrderModule {
    using SafeCast for uint256;
    using SafeERC20 for IERC20;
    using MarketOrder for MarketOrder.Data;
    using PerpsAccount for PerpsAccount.Data;
    using GlobalConfiguration for GlobalConfiguration.Data;
    using PerpMarket for PerpMarket.Data;
    using Position for Position.Data;

    /// @inheritdoc IOrderModule
    function getConfiguredOrderFees(uint128 marketId) external view override returns (OrderFees.Data memory) {
        return PerpMarket.load(marketId).configuration.orderFees;
    }

    /// @inheritdoc IOrderModule
    function simulateSettlement(
        uint128 marketId,
        uint128 settlementId,
        int128 sizeDelta
    )
        external
        view
        override
        returns (SD59x18, UD60x18, UD60x18)
    {
        PerpMarket.Data storage perpMarket = PerpMarket.load(marketId);
        SettlementConfiguration.Data storage settlementConfiguration =
            SettlementConfiguration.load(marketId, settlementId);

        UD60x18 indexPriceX18 = perpMarket.getIndexPrice();
        UD60x18 markPriceX18 = perpMarket.getMarkPrice(sd59x18(sizeDelta), indexPriceX18);

        SD59x18 orderFeeUsdX18 = perpMarket.getOrderFeeUsd(sd59x18(sizeDelta), markPriceX18);

        UD60x18 settlementFeeUsdX18 = ud60x18(uint256(settlementConfiguration.fee));

        return (orderFeeUsdX18, settlementFeeUsdX18, markPriceX18);
    }

    /// @inheritdoc IOrderModule
    function getRequiredMarginForOrder(
        uint128 marketId,
        int128 sizeDelta
    )
        external
        view
        override
        returns (UD60x18, UD60x18)
    { }

    /// @inheritdoc IOrderModule
    function getActiveMarketOrder(
        uint128 accountId,
        uint128 marketId
    )
        external
        pure
        override
        returns (MarketOrder.Data memory marketOrder)
    {
        marketOrder = MarketOrder.load(accountId, marketId);
    }

    /// @inheritdoc IOrderModule
    function createMarketOrder(
        uint128 accountId,
        uint128 marketId,
        int128 sizeDelta,
        uint128 acceptablePrice
    )
        external
        override
    {
        PerpsAccount.Data storage perpsAccount = PerpsAccount.loadExistingAccountAndVerifySender(accountId);
        MarketOrder.Data storage marketOrder = MarketOrder.load(accountId, marketId);
        GlobalConfiguration.Data storage globalConfiguration = GlobalConfiguration.load();

        if (sizeDelta == 0) {
            revert Errors.ZeroInput("sizeDelta");
        }

        perpsAccount.validateMarginRequirements(marketId, sd59x18(sizeDelta));

        bool isMarketWithActivePosition = perpsAccount.isMarketWithActivePosition(marketId);
        if (!isMarketWithActivePosition) {
            perpsAccount.validatePositionsLimit();
        }

        globalConfiguration.checkMarketIsEnabled(marketId);
        marketOrder.checkPendingOrder();

        marketOrder.update({ sizeDelta: sizeDelta, acceptablePrice: acceptablePrice });

        emit LogCreateMarketOrder(msg.sender, accountId, marketId, marketOrder);
    }

    function dispatchCustomSettlementRequest(
        uint128 accountId,
        uint128 marketId,
        uint128 settlementId,
        bool isAccountStrategy,
        bytes calldata extraData
    )
        external
        override
        returns (bytes memory)
    {
        PerpsAccount.verifySender(accountId);
        SettlementConfiguration.Data storage settlementConfiguration;

        if (!isAccountStrategy) {
            settlementConfiguration = SettlementConfiguration.load(marketId, settlementId);
        } else {
            // TODO: Implement
            // settlementConfiguration = SettlementConfiguration.load(accountId, marketId, settlementId);
            settlementConfiguration = SettlementConfiguration.load(marketId, settlementId);
        }

        address settlementStrategy = settlementConfiguration.settlementStrategy;

        bytes memory callData = abi.encodeWithSelector(ISettlementStrategy.dispatch.selector, accountId, extraData);
        (bool success, bytes memory returnData) = settlementStrategy.call(callData);

        if (!success) {
            if (returnData.length == 0) revert Errors.FailedDispatchCustomSettlementRequest();
            assembly {
                revert(add(returnData, 0x20), mload(returnData))
            }
        }

        return returnData;
    }

    /// @inheritdoc IOrderModule
    function cancelMarketOrder(uint128 accountId, uint128 marketId) external override {
        MarketOrder.Data storage marketOrder = MarketOrder.load(accountId, marketId);

        if (marketOrder.timestamp == 0) {
            revert Errors.MarketOrderNotFound(accountId, marketId);
        }

        marketOrder.clear();

        emit LogCancelMarketOrder(msg.sender, accountId, marketId);
    }
}
