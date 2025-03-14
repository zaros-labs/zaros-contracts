// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Constants } from "@zaros/utils/Constants.sol";
import { Markets } from "script/markets/Markets.sol";
import { Vaults } from "script/vaults/Vaults.sol";
import { MarginCollaterals } from "script/margin-collaterals/MarginCollaterals.sol";
import { SequencerUptimeFeeds } from "script/sequencer-uptime-feeds/SequencerUptimeFeeds.sol";
import { PerpMarketsCreditConfig } from "script/perp-markets-credit-config/PerpMarketsCreditConfig.sol";
import { DexAdapterUtils } from "script/utils/DexAdapterUtils.sol";
import { MarketMakingEngineCollaterals } from
    "script/market-making-engine-collaterals/MarketMakingEngineCollaterals.sol";

// PRB Math dependencies
import { uMAX_UD60x18 as LIB_uMAX_UD60x18 } from "@prb-math/UD60x18.sol";
import { uMAX_SD59x18 as LIB_uMAX_SD59x18, uMIN_SD59x18 as LIB_uMIN_SD59x18 } from "@prb-math/SD59x18.sol";

abstract contract ProtocolConfiguration is
    Markets,
    MarginCollaterals,
    Vaults,
    SequencerUptimeFeeds,
    PerpMarketsCreditConfig,
    DexAdapterUtils,
    MarketMakingEngineCollaterals
{
    /// @notice Admin addresses.

    // TODO: Update to actual multisig address
    address internal constant MSIG_ADDRESS = 0xE2658E63c85D8a469324afA377Bf5694cd55bD7B;

    /// @notice The maximum value that can be represented in a UD60x18.
    uint256 internal constant uMAX_UD60x18 = LIB_uMAX_UD60x18;

    /// @notice The maximum value that can be represented in a SD59x18.
    int256 internal constant uMAX_SD59x18 = LIB_uMAX_SD59x18;

    /// @notice The minimum value that can be represented in a SD59x18.
    int256 internal constant uMIN_SD59x18 = LIB_uMIN_SD59x18;

    /// @notice The default decimals value used in the protocol.
    uint8 internal constant SYSTEM_DECIMALS = Constants.SYSTEM_DECIMALS;

    /// @notice Chainlink Automation keepers configuration parameters.
    string internal constant PERPS_LIQUIDATION_KEEPER_NAME = "Perps Liquidation Keeper";

    /// @notice Settlement Strategies configuration parameters.
    uint256 internal constant LIMIT_ORDER_CONFIGURATION_ID = 1;
    uint256 internal constant OCO_ORDER_CONFIGURATION_ID = 2;
    uint128 internal constant MAX_ACTIVE_LIMIT_ORDERS_PER_ACCOUNT_PER_MARKET = 5;

    /// @notice General perps engine system configuration parameters.
    uint128 internal constant MAX_POSITIONS_PER_ACCOUNT = 10;
    uint128 internal constant MARKET_ORDER_MIN_LIFETIME = 10 seconds;
    uint128 internal constant LIQUIDATION_FEE_USD = 5e18;

    /// @notice Test only mocks and constants.
    uint256 internal constant INITIAL_MARKET_ID = 1;
    uint256 internal constant FINAL_MARKET_ID = 10;
    uint256 internal constant INITIAL_MARGIN_COLLATERAL_ID = 1;
    uint256 internal constant FINAL_MARGIN_COLLATERAL_ID = 6;
    uint256 internal constant MAX_MARGIN_REQUIREMENTS = 1e18;
    uint256 internal constant MOCK_DATA_STREAMS_EXPIRATION_DELAY = 5 seconds;
    uint128 internal constant INITIAL_VAULT_ID = 1;
    uint128 internal constant FINAL_VAULT_ID = 17;
    uint128 internal constant INVALID_VAULT_ID = 0;
    uint128 internal constant INITIAL_PERP_MARKET_CREDIT_CONFIG_ID = 1;
    uint128 internal constant FINAL_PERP_MARKET_CREDIT_CONFIG_ID = 10;

    /// @notice The maximum delay allowed for the off chain price verification.
    uint256 internal constant MAX_VERIFICATION_DELAY = 60 seconds;

    /// @notice Dex adapter related constants
    uint256 internal constant SLIPPAGE_TOLERANCE_BPS = 100;
    uint24 internal constant UNI_V3_FEE = 3000;

    /// @notice General market making engine system configuration parameters.
    uint256 internal constant MSIG_SHARES_FEE_RECIPIENT = 0.3e18;
    uint256 internal constant INITIAL_MARKET_MAKING_ENGINE_COLLATERAL_ID = 1;
    uint256 internal constant FINAL_MARKET_MAKING_ENGINE_COLLATERAL_ID = 4;
}
