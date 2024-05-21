// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

abstract contract Usdz {
    /// @notice Margin collateral configuration parameters.
    uint256 internal constant USDZ_MARGIN_COLLATERAL_ID = 2;
    uint128 internal constant USDZ_DEPOSIT_CAP = 50_000_000_000e18;
    uint120 internal constant USDZ_LOAN_TO_VALUE = 1e18;
    uint256 internal constant USDZ_MIN_DEPOSIT_MARGIN = 50e18;
    uint256 internal constant MOCK_USDZ_USD_PRICE = 1e6;
}
