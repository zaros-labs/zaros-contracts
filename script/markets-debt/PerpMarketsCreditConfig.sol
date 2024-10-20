// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { IMarketMakingEngine } from "@zaros/market-making/MarketMakingEngine.sol";

// Forge dependencies
import { StdCheats, StdUtils } from "forge-std/Test.sol";

// Markets Debt
import { BtcPerpMarketCreditConfig } from "script/markets-debt/BtcPerpMarketCreditConfig.sol";
import { EthPerpMarketCreditConfig } from "script/markets-debt/EthPerpMarketCreditConfig.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18 } from "@prb-math/SD59x18.sol";

/// @notice PerpMarketsCreditConfig contract
abstract contract PerpMarketsCreditConfig is StdCheats, StdUtils, BtcPerpMarketCreditConfig, EthPerpMarketCreditConfig {

    /// @notice Market debt config
    /// @param marketDebtId Market debt id
    /// @param autoDeleverageStartThreshold Auto deleverage start threshold
    /// @param autoDeleverageEndThreshold Auto deleverage end threshold
    /// @param autoDeleveragePowerScale Auto deleverage power scale
    /// @param marketShare Market share
    /// @param feeRecipientsShare Fee recipients share
    struct MarketDebtConfig {
        uint128 marketDebtId;
        uint128 autoDeleverageStartThreshold;
        uint128 autoDeleverageEndThreshold;
        uint128 autoDeleveragePowerScale;
        uint128 marketShare;
        uint128 feeRecipientsShare;
    }

    /// @notice Configure market debts params
    /// @param marketMakingEngine Market making engine
    /// @param initialMarketDebtId Initial market debt id
    /// @param finalMarketDebtId Final market debt id
    struct ConfigureMarketDebtsParams {
        IMarketMakingEngine marketMakingEngine;
        uint256 initialMarketDebtId;
        uint256 finalMarketDebtId;
    }

    /// @notice Market debt configurations mapped by market debtid.
    mapping(uint256 marketDebtId => MarketDebtConfig marketConfig) internal marketsDebtConfig;

    /// @notice Setup markets debt config
    function setupMarketsDebtConfig() internal {
        marketsDebtConfig[BTC_PERP_MARKET_CREDIT_CONFIG_ID] = MarketDebtConfig({
            marketDebtId: BTC_PERP_MARKET_CREDIT_CONFIG_ID,
            autoDeleverageStartThreshold: BTC_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_START_THRESHOLD,
            autoDeleverageEndThreshold: BTC_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_END_THRESHOLD,
            autoDeleveragePowerScale: BTC_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_POWER_SCALE,
            marketShare: BTC_PERP_MARKET_CREDIT_CONFIG_MARKET_SHARE,
            feeRecipientsShare: BTC_PERP_MARKET_CREDIT_CONFIG_FEE_RECIPIENTS_SHARE
        });

        marketsDebtConfig[ETH_PERP_MARKET_CREDIT_CONFIG_ID] = MarketDebtConfig({
            marketDebtId: ETH_PERP_MARKET_CREDIT_CONFIG_ID,
            autoDeleverageStartThreshold: ETH_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_START_THRESHOLD,
            autoDeleverageEndThreshold: ETH_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_END_THRESHOLD,
            autoDeleveragePowerScale: ETH_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_POWER_SCALE,
            marketShare: ETH_PERP_MARKET_CREDIT_CONFIG_MARKET_SHARE,
            feeRecipientsShare: ETH_PERP_MARKET_CREDIT_CONFIG_FEE_RECIPIENTS_SHARE
        });
    }

    /// @notice Get filtered markets debt config
    /// @param marketsDebtIdsRange Markets debt ids range
    function getFilteredMarketsDebtConfig(
        uint256[2] memory marketsDebtIdsRange
    )
        internal
        view
        returns (MarketDebtConfig[] memory)
    {
        uint256 initialMarketId = marketsDebtIdsRange[0];
        uint256 finalMarketId = marketsDebtIdsRange[1];
        uint256 filteredMarketsDebtLength = finalMarketId - initialMarketId + 1;

        MarketDebtConfig[] memory filteredMarketsDebtConfig = new MarketDebtConfig[](filteredMarketsDebtLength);

        uint256 nextMarketDebtId = initialMarketId;
        for (uint256 i; i < filteredMarketsDebtLength; i++) {
            filteredMarketsDebtConfig[i] = marketsDebtConfig[nextMarketDebtId];
            nextMarketDebtId++;
        }

        return filteredMarketsDebtConfig;
    }

    /// @notice Configure markets debt
    /// @param params Configure market debts params
    function configureMarketsDebt(ConfigureMarketDebtsParams memory params) public {
        for (uint256 i = params.initialMarketDebtId; i <= params.finalMarketDebtId; i++) {
            params.marketMakingEngine.configureMarketDebt(
                marketsDebtConfig[i].marketDebtId,
                marketsDebtConfig[i].autoDeleverageStartThreshold,
                marketsDebtConfig[i].autoDeleverageEndThreshold,
                marketsDebtConfig[i].autoDeleveragePowerScale,
                marketsDebtConfig[i].marketShare,
                marketsDebtConfig[i].feeRecipientsShare
            );
        }
    }
}
