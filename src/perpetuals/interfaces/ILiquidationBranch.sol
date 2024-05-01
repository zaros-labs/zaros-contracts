// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

interface ILiquidationBranch {
    event LogLiquidateAccount(
        address indexed keeper,
        uint128 indexed accountId,
        address feeRecipient,
        uint256 amountOfOpenPositions,
        uint256 requiredMaintenanceMarginUsd,
        int256 marginBalanceUsd,
        uint256 liquidatedCollateralUsd,
        uint128 liquidationFeeUsd
    );

    function checkLiquidatableAccounts(
        uint256 lowerBound,
        uint256 upperBound
    )
        external
        view
        returns (uint128[] memory liquidatableAccountsIds);

    function liquidateAccounts(uint128[] calldata accountsIds, address feeRecipient) external;
}
