//SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

/**
 * @title System-wide entry point for the management of markets connected to the system.
 */
interface IMarketManagerModule {
    /**
     * @notice Thrown when a market does not have enough liquidity for a withdrawal.
     */
    error Zaros_MarketManagerModule_NotEnoughLiquidity(address marketAddress, uint256 amount);

    /**
     * @notice Emitted when a new market is registered in the system.
     * @param marketAddress The id with which the market was registered in the system.
     * @param sender The account that trigger the registration of the market.
     */
    event MarketRegistered(address indexed marketAddress, address indexed sender);

    /**
     * @notice Emitted when a market deposits zrsUSD in the system.
     * @param marketAddress The id of the market that deposited zrsUSD in the system.
     * @param target The address of the account that provided the zrsUSD in the deposit.
     * @param amount The amount of zrsUSD deposited in the system, denominated with 18 decimals of precision.
     */
    event MarketUsdDeposited(address indexed marketAddress, address indexed target, uint256 amount);

    /**
     * @notice Emitted when a market withdraws zrsUSD from the system.
     * @param marketAddress The id of the market that withdrew zrsUSD from the system.
     * @param target The address of the account that received the zrsUSD in the withdrawal.
     * @param amount The amount of zrsUSD withdrawn from the system, denominated with 18 decimals of precision.
     */
    event MarketUsdWithdrawn(address indexed marketAddress, address indexed target, uint256 amount);

    event MarketSystemFeePaid(address indexed marketAddress, uint256 feeAmount);

    /**
     * @notice Emitted when a market sets an updated minimum delegation time
     * @param marketAddress The id of the market that the setting is applied to
     * @param minDelegateTime The minimum amount of time between delegation changes
     */
    event SetMinDelegateTime(address indexed marketAddress, uint32 minDelegateTime);

    /**
     * @notice Emitted when a market-specific minimum liquidity ratio is set
     * @param marketAddress The id of the market that the setting is applied to
     * @param minLiquidityRatio The new market-specific minimum liquidity ratio
     */
    event SetMarketMinLiquidityRatio(address indexed marketAddress, uint256 minLiquidityRatio);

    // function depositMarketUsd(
    //     address marketAddress,
    //     address target,
    //     uint256 amount
    // )
    //     external
    //     returns (uint256 feeAmount);

    // function withdrawMarketUsd(
    //     address marketAddress,
    //     address target,
    //     uint256 amount
    // )
    //     external
    //     returns (uint256 feeAmount);

    function getWithdrawableMarketUsd(address marketAddress) external view returns (uint256 withdrawable);

    function getMarketNetIssuance(address marketAddress) external view returns (int128 issuance);

    function getMarketReportedDebt(address marketAddress) external view returns (uint256 reportedDebt);

    function getMarketTotalDebt(address marketAddress) external view returns (int256 totalDebt);

    function getMarketCollateral(address marketAddress) external view returns (uint256 value);

    function getMarketDebtPerCredit(address marketAddress) external returns (int256 debtPerShare);

    function isMarketCapacityLocked(address marketAddress) external view returns (bool isLocked);

    function getZarosUsd() external view returns (address);

    function setMinLiquidityRatio(address marketAddress, uint128 minLiquidityRatio) external;

    function getMinLiquidityRatio(address marketAddress) external view returns (uint256 minRatio);
}
