// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Constants } from "@zaros/utils/Constants.sol";
import { OrderFees } from "@zaros/perpetuals/leaves/OrderFees.sol";
import { Markets } from "script/markets/Markets.sol";
import { MarginCollaterals } from "script/marginCollaterals/MarginCollaterals.sol";

// PRB Math dependencies
import { uMAX_UD60x18 as LIB_uMAX_UD60x18 } from "@prb-math/UD60x18.sol";
import { uMAX_SD59x18 as LIB_uMAX_SD59x18, uMIN_SD59x18 as LIB_uMIN_SD59x18 } from "@prb-math/SD59x18.sol";

abstract contract ProtocolConfiguration is Markets, MarginCollaterals {
    /// @notice Admin addresses.

    // TODO: Update to actual multisig address
    address internal constant MSIG_ADDRESS = 0xeA6930f85b5F52507AbE7B2c5aF1153391BEb2b8;

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

    /// @notice Chainlink Automation keepers configuration parameters.
    string internal constant PERPS_LIQUIDATION_KEEPER_NAME = "Perps Liquidation Keeper";

    /// @notice Settlement Strategies configuration parameters.
    uint256 internal constant LIMIT_ORDER_CONFIGURATION_ID = 1;
    uint256 internal constant OCO_ORDER_CONFIGURATION_ID = 2;
    uint128 internal constant MAX_ACTIVE_LIMIT_ORDERS_PER_ACCOUNT_PER_MARKET = 5;

    /// @notice General perps engine system configuration parameters.
    uint128 internal constant MAX_POSITIONS_PER_ACCOUNT = 10;
    uint128 internal constant MARKET_ORDER_MAX_LIFETIME = 10 seconds;
    uint128 internal constant LIQUIDATION_FEE_USD = 5e18;

    /// @notice Test only mocks and constants.
    uint256 internal constant INITIAL_MARKET_ID = 1;
    uint256 internal constant FINAL_MARKET_ID = 4;

    uint256 internal constant MAX_MARGIN_REQUIREMENTS = 1e18;
    uint256 internal constant MOCK_DATA_STREAMS_EXPIRATION_DELAY = 5 seconds;
}
