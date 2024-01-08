// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { Constants as ProtocolConstants } from "@zaros/utils/Constants.sol";

// PRB Math dependencies
import { uMAX_UD60x18 as LIB_uMAX_UD60x18 } from "@prb-math/UD60x18.sol";
import { uMAX_SD59x18 as LIB_uMAX_SD59x18, uMIN_SD59x18 as LIB_uMIN_SD59x18 } from "@prb-math/SD59x18.sol";

abstract contract Constants {
    /// @notice The maximum value that can be represented in a UD60x18.
    uint256 internal constant uMAX_UD60x18 = LIB_uMAX_UD60x18;

    /// @notice The maximum value that can be represented in a SD59x18.
    int256 internal constant uMAX_SD59x18 = LIB_uMAX_SD59x18;

    /// @notice The minimum value that can be represented in a SD59x18.
    int256 internal constant uMIN_SD59x18 = LIB_uMIN_SD59x18;

    /// @notice The default decimals value used in the protocol.
    uint8 internal constant DEFAULT_DECIMALS = ProtocolConstants.SYSTEM_DECIMALS;

    /// @notice Feature flags for all permissionless features.
    bytes32 internal constant CREATE_ACCOUNT_FEATURE_FLAG = ProtocolConstants.CREATE_ACCOUNT_FEATURE_FLAG;
    bytes32 internal constant DEPOSIT_FEATURE_FLAG = ProtocolConstants.DEPOSIT_FEATURE_FLAG;
    bytes32 internal constant WITHDRAW_FEATURE_FLAG = ProtocolConstants.WITHDRAW_FEATURE_FLAG;
    bytes32 internal constant CLAIM_FEATURE_FLAG = ProtocolConstants.CLAIM_FEATURE_FLAG;
    bytes32 internal constant DELEGATE_FEATURE_FLAG = ProtocolConstants.DELEGATE_FEATURE_FLAG;

    /// @notice Zaros USD permissioned features.
    bytes32 internal constant BURN_FEATURE_FLAG = ProtocolConstants.BURN_FEATURE_FLAG;
    bytes32 internal constant MINT_FEATURE_FLAG = ProtocolConstants.MINT_FEATURE_FLAG;

    /// @notice Margin collateral types configuration constants.
    uint248 internal constant USDC_DEPOSIT_CAP = 50_000_000_000e18;
    uint248 internal constant USDZ_DEPOSIT_CAP = 50_000_000_000e18;
    uint248 internal constant WSTETH_DEPOSIT_CAP = 1_000_000e18;
    uint256 internal constant USDC_MIN_DEPOSIT_MARGIN = 50e18;
    uint256 internal constant USDZ_MIN_DEPOSIT_MARGIN = 50e18;
    uint256 internal constant WSTETH_MIN_DEPOSIT_MARGIN = 0.025e18;

    /// @notice General perps markets configuration constants.
    string internal constant DATA_STREAMS_FEED_PARAM_KEY = "feedIDs";
    string internal constant DATA_STREAMS_TIME_PARAM_KEY = "timestamp";
    uint80 internal constant DATA_STREAMS_SETTLEMENT_FEE = 1e18;
    uint128 internal constant MAX_POSITIONS_PER_ACCOUNT = 10;
    uint128 internal constant MARKET_ORDER_MAX_LIFETIME = 10 seconds;
    uint256 internal constant MAX_IMR = 100e18;
    uint256 internal constant MOCK_DATA_STREAMS_EXPIRATION_DELAY = 5 seconds;

    /// @notice BTC/USD market configuration constants.
    uint128 internal constant BTC_USD_MARKET_ID = 1;
    string internal constant BTC_USD_MARKET_NAME = "BTC/USD Perpetual Futures";
    string internal constant BTC_USD_MARKET_SYMBOL = "BTC/USD PERP";
    string internal constant MOCK_BTC_USD_STREAM_ID = "MOCK_BTC_USD_STREAM_ID";
    uint128 internal constant BTC_USD_MIN_IMR = 0.01e18;
    uint128 internal constant BTC_USD_MMR = 0.01e18;
    uint128 internal constant BTC_USD_MAX_OI = 100_000_000e18;
    uint256 internal constant BTC_USD_SKEW_SCALE = 1_000_000e18;
    uint128 internal constant BTC_USD_MAX_FUNDING_VELOCITY = 0.025e18;
    uint128 internal constant BTC_USD_ORDER_MAKER_FEE = 0.04e18;
    uint128 internal constant BTC_USD_ORDER_TAKER_FEE = 0.08e18;
    uint248 internal constant BTC_USD_SETTLEMENT_DELAY = 1 seconds;

    /// @notice ETH/USD market configuration constants.
    uint128 internal constant ETH_USD_MARKET_ID = 2;
    string internal constant ETH_USD_MARKET_NAME = "ETH/USD Perpetual Futures";
    string internal constant ETH_USD_MARKET_SYMBOL = "ETH/USD PERP";
    string internal constant MOCK_ETH_USD_STREAM_ID = "MOCK_ETH_USD_STREAM_ID";
    uint128 internal constant ETH_USD_MIN_IMR = 0.01e18;
    uint128 internal constant ETH_USD_MMR = 0.01e18;
    uint128 internal constant ETH_USD_MAX_OI = 100_000_000e18;
    uint256 internal constant ETH_USD_SKEW_SCALE = 1_000_000e18;
    uint128 internal constant ETH_USD_MAX_FUNDING_VELOCITY = 0.025e18;
    uint128 internal constant ETH_USD_ORDER_MAKER_FEE = 0.04e18;
    uint128 internal constant ETH_USD_ORDER_TAKER_FEE = 0.08e18;
    uint248 internal constant ETH_USD_SETTLEMENT_DELAY = 1 seconds;

    /// @notice Mocked prices.
    uint256 internal constant MOCK_BTC_USD_PRICE = 100_000e18;
    uint256 internal constant MOCK_ETH_USD_PRICE = 1000e18;
    uint256 internal constant MOCK_USDC_USD_PRICE = 1e6;
    uint256 internal constant MOCK_WSTETH_USD_PRICE = 2000e18;
}
