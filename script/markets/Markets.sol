// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { Constants } from "@zaros/utils/Constants.sol";
import { OrderFees } from "@zaros/markets/perps/storage/OrderFees.sol";

// PRB Math dependencies
import { uMAX_UD60x18 as LIB_uMAX_UD60x18 } from "@prb-math/UD60x18.sol";
import { uMAX_SD59x18 as LIB_uMAX_SD59x18, uMIN_SD59x18 as LIB_uMIN_SD59x18 } from "@prb-math/SD59x18.sol";

// Markets
import { ArbUsd } from "./ArbUsd.sol";
import { BtcUsd } from "./BtcUsd.sol";
import { EthUsd } from "./EthUsd.sol";
import { LinkUsd } from "./LinkUsd.sol";

contract Markets is ArbUsd, BtcUsd, EthUsd, LinkUsd {

    /// @notice Settlement Strategies configuration Constants.
    uint256 internal constant LIMIT_ORDER_SETTLEMENT_ID = 1;
    uint256 internal constant OCO_ORDER_SETTLEMENT_ID = 2;
    uint80 internal constant DEFAULT_SETTLEMENT_FEE = 2e18;
    uint128 internal constant MAX_ACTIVE_LIMIT_ORDERS_PER_ACCOUNT_PER_MARKET = 5;

    /// @notice General perps engine system configuration Constants.
    string internal constant DATA_STREAMS_FEED_PARAM_KEY = "feedIDs";
    string internal constant DATA_STREAMS_TIME_PARAM_KEY = "timestamp";
    uint80 internal constant DATA_STREAMS_SETTLEMENT_FEE = 1e18;
    uint128 internal constant MAX_POSITIONS_PER_ACCOUNT = 10;
    uint128 internal constant MARKET_ORDER_MAX_LIFETIME = 10 seconds;
    uint128 internal constant MIN_TRADE_SIZE_USD = 200e18;
    uint128 internal constant LIQUIDATION_FEE_USD = 5e18;

    // TODO: Update to actual EDAO multisig address
    address internal constant EDAO_ADDRESS = 0xeA6930f85b5F52507AbE7B2c5aF1153391BEb2b8;

    /// @notice The maximum value that can be represented in a UD60x18.
    uint256 internal constant uMAX_UD60x18 = LIB_uMAX_UD60x18;

    /// @notice The maximum value that can be represented in a SD59x18.
    int256 internal constant uMAX_SD59x18 = LIB_uMAX_SD59x18;

    /// @notice The minimum value that can be represented in a SD59x18.
    int256 internal constant uMIN_SD59x18 = LIB_uMIN_SD59x18;

    /// @notice The default decimals value used in the protocol.
    uint8 internal constant SYSTEM_DECIMALS = Constants.SYSTEM_DECIMALS;

    /// @notice Feature flags for all permissionless features.
    bytes32 internal constant CREATE_ACCOUNT_FEATURE_FLAG = Constants.CREATE_ACCOUNT_FEATURE_FLAG;
    bytes32 internal constant DEPOSIT_FEATURE_FLAG = Constants.DEPOSIT_FEATURE_FLAG;
    bytes32 internal constant WITHDRAW_FEATURE_FLAG = Constants.WITHDRAW_FEATURE_FLAG;
    bytes32 internal constant CLAIM_FEATURE_FLAG = Constants.CLAIM_FEATURE_FLAG;
    bytes32 internal constant DELEGATE_FEATURE_FLAG = Constants.DELEGATE_FEATURE_FLAG;

    /// @notice Zaros USD permissioned features.
    bytes32 internal constant BURN_FEATURE_FLAG = Constants.BURN_FEATURE_FLAG;
    bytes32 internal constant MINT_FEATURE_FLAG = Constants.MINT_FEATURE_FLAG;

    /// @notice Chainlink Automation upkeeps configuration Constants.
    string internal constant PERPS_LIQUIDATION_UPKEEP_NAME = "Perps Liquidation Upkeep";

    /// @notice Margin collateral types configuration Constants.
    uint128 internal constant USDC_DEPOSIT_CAP = 5_000_000_000e18;
    uint128 internal constant USDZ_DEPOSIT_CAP = 50_000_000_000e18;
    uint128 internal constant WSTETH_DEPOSIT_CAP = 1_000_000e18;
    uint120 internal constant USDC_LOAN_TO_VALUE = 1e18;
    uint120 internal constant USDZ_LOAN_TO_VALUE = 1e18;
    uint120 internal constant WSTETH_LOAN_TO_VALUE = 0.7e18;
    uint256 internal constant USDC_MIN_DEPOSIT_MARGIN = 50e18;
    uint256 internal constant USDZ_MIN_DEPOSIT_MARGIN = 50e18;
    uint256 internal constant WSTETH_MIN_DEPOSIT_MARGIN = 0.025e18;

    /// @notice Test only mocks
    uint256 internal constant MOCK_BTC_USD_PRICE = 100_000e18;
    uint256 internal constant MOCK_ETH_USD_PRICE = 1000e18;
    uint256 internal constant MOCK_USDC_USD_PRICE = 1e6;
    uint256 internal constant MOCK_WSTETH_USD_PRICE = 2000e18;
    uint256 internal constant MAX_MARGIN_REQUIREMENTS = 1e18;
    uint256 internal constant MOCK_DATA_STREAMS_EXPIRATION_DELAY = 5 seconds;
    string internal constant MOCK_BTC_USD_STREAM_ID = "MOCK_BTC_USD_STREAM_ID";
    string internal constant MOCK_ETH_USD_STREAM_ID = "MOCK_ETH_USD_STREAM_ID";

    struct MarketConfig {
        uint128 marketId;
        string marketName;
        string marketSymbol;
        uint128 imr;
        uint128 mmr;
        uint128 marginRequirements;
        uint128 maxOi;
        uint256 skewScale;
        uint128 maxFundingVelocity;
        uint128 settlementDelay;
        address priceAdapter;
        string streamId;
        OrderFees.Data orderFees;
    }

    function getMarketsConfig(address[] memory addressPriceFeeds, string[] memory streamIds) internal pure returns(MarketConfig[] memory){

        MarketConfig[] memory marketsConfig = new MarketConfig[](2);

        MarketConfig memory ethUsdConfig = MarketConfig({
            marketId: ETH_USD_MARKET_ID,
            marketName: ETH_USD_MARKET_NAME,
            marketSymbol: ETH_USD_MARKET_SYMBOL,
            imr: ETH_USD_IMR,
            mmr: ETH_USD_MMR,
            marginRequirements: ETH_USD_MARGIN_REQUIREMENTS,
            maxOi: ETH_USD_MAX_OI,
            skewScale: ETH_USD_SKEW_SCALE,
            maxFundingVelocity: ETH_USD_MAX_FUNDING_VELOCITY,
            settlementDelay: ETH_USD_SETTLEMENT_DELAY,
            priceAdapter: addressPriceFeeds[0],
            streamId: streamIds[0],
            orderFees: OrderFees.Data({ makerFee: 0.0004e18, takerFee: 0.0008e18 })
        });
        marketsConfig[0] = ethUsdConfig;

        MarketConfig memory linkUsdConfig = MarketConfig({
            marketId: LINK_USD_MARKET_ID,
            marketName: LINK_USD_MARKET_NAME,
            marketSymbol: LINK_USD_MARKET_SYMBOL,
            imr: LINK_USD_IMR,
            mmr: LINK_USD_MMR,
            marginRequirements: LINK_USD_MARGIN_REQUIREMENTS,
            maxOi: LINK_USD_MAX_OI,
            skewScale: LINK_USD_SKEW_SCALE,
            maxFundingVelocity: LINK_USD_MAX_FUNDING_VELOCITY,
            settlementDelay: LINK_USD_SETTLEMENT_DELAY,
            priceAdapter: addressPriceFeeds[1],
            streamId: streamIds[1],
            orderFees: OrderFees.Data({ makerFee: 0.0004e18, takerFee: 0.0008e18 })
        });
        marketsConfig[1] = linkUsdConfig;

        return marketsConfig;
    }
}
