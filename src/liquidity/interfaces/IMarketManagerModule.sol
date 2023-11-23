//SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { MarketConfiguration } from "../storage/MarketConfiguration.sol";

interface IMarketManagerModule {
    error Zaros_MarketManagerModule_NotEnoughLiquidity(address marketAddress, uint256 amount);

    event SetMinDelegateTime(address indexed marketAddress, uint32 minDelegateTime);

    event LogSetMinLiquidityRatio(address indexed marketAddress, uint256 minLiquidityRatio);

    event LogConfigureMarkets(address indexed sender, MarketConfiguration.Data[] marketConfigurations);

    function getWithdrawableMarketUsd(address marketAddress) external view returns (uint256 withdrawable);

    function getMarketNetIssuance(address marketAddress) external view returns (int128 issuance);

    function getMarketReportedDebt(address marketAddress) external view returns (uint256 reportedDebt);

    function getMarketTotalDebt(address marketAddress) external view returns (int256 totalDebt);

    function getMarketCollateral(address marketAddress) external view returns (uint256 value);

    function getMarketDebtPerCredit(address marketAddress) external returns (int256 debtPerShare);

    function isMarketCapacityLocked(address marketAddress) external view returns (bool isLocked);

    function getUsdToken() external view returns (address);

    function getMinLiquidityRatio(address marketAddress) external view returns (uint256 minRatio);

    function setMinLiquidityRatio(address marketAddress, uint128 minLiquidityRatio) external;

    function configureMarkets(MarketConfiguration.Data[] calldata marketConfigurations) external;
}
