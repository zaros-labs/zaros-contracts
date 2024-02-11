// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

interface ILiquidationModule {
    event LogLiquidateAccount(
        address indexed keeper,
        uint128 indexed accountId,
        uint256 amountOfOpenPositions,
        uint256 requiredMaintenanceMarginUsdX18,
        int256 marginBalanceUsdX18,
        uint256 liquidatedCollateralUsdX18,
        uint256 liquidationFeeUsdX18
    );

    function checkLiquidatableAccounts(uint128[] calldata accountsIds)
        external
        view
        returns (uint128[] memory liquidatableAccountsIds);

    function liquidateAccounts(uint128[] calldata accountsIds) external;
}
