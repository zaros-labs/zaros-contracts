// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

abstract contract WeEth {
    /// @notice Margin collateral configuration parameters.
    uint256 internal constant WEETH_MARGIN_COLLATERAL_ID = 6;
    uint128 internal constant WEETH_DEPOSIT_CAP = 1_000_000e18;
    uint120 internal constant WEETH_LOAN_TO_VALUE = 0.7e18;
    uint256 internal constant WEETH_MIN_DEPOSIT_MARGIN = 0.025e18;
    uint256 internal constant MOCK_WEETH_USD_PRICE = 2000e18;
    address internal constant WEETH_ADDRESS = address(0xd9433D0E5b5Ae4593ba3880c25046BBC4dC4926C);
    address internal constant WEETH_PRICE_FEED = address(0xd9433D0E5b5Ae4593ba3880c25046BBC4dC4926C);
    uint256 internal constant WEETH_LIQUIDATION_PRIORITY = 6;
    uint8 internal constant WEETH_DECIMALS = 18;
}
