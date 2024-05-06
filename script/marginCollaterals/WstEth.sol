// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

abstract contract WstEth {
    /// @notice Margin collateral configuration parameters.
    uint128 internal constant WSTETH_DEPOSIT_CAP = 1_000_000e18;
    uint120 internal constant WSTETH_LOAN_TO_VALUE = 0.7e18;
    uint256 internal constant WSTETH_MIN_DEPOSIT_MARGIN = 0.025e18;
    uint256 internal constant MOCK_WSTETH_USD_PRICE = 2000e18;
}
