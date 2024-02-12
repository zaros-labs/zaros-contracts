// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

interface ILiquidationModule {
    event LogLiquidateAccount(
        address indexed keeper,
        uint128 indexed accountId,
        address feeReceiver,
        uint256 amountOfOpenPositions,
        uint256 requiredMaintenanceMarginUsd,
        int256 marginBalanceUsd,
        uint256 liquidatedCollateralUsd,
        uint256 liquidationFeeUsd
    );

    function checkLiquidatableAccounts(uint128[] calldata accountsIds)
        external
        view
        returns (uint128[] memory liquidatableAccountsIds);

    function liquidateAccounts(uint128[] calldata accountsIds, address feeReceiver) external;
}
