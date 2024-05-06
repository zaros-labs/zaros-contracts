// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

abstract contract Usdc {
    /// @notice Margin collateral configuration parameters.
    uint128 internal constant USDC_DEPOSIT_CAP = 5_000_000_000e18;
    uint120 internal constant USDC_LOAN_TO_VALUE = 1e18;
    uint256 internal constant USDC_MIN_DEPOSIT_MARGIN = 50e18;
    uint256 internal constant MOCK_USDC_USD_PRICE = 1e6;
}
