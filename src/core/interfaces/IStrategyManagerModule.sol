// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

interface IStrategyManagerModule {
    error Zaros_StrategyManagerModule_InvalidSender(address sender, address strategyHandler);

    error Zaros_StrategyManagerModule_StrategyNotRegistered(address collateralType);

    error Zaros_StrategyManagerModule_BorrowCapReached(uint128 borrowCap, uint128 borrowedUsd, uint256 amount);

    error Zaros_StrategyManagerModule_OutputTooLow(uint256 amount, uint256 minAmount);

    event LogRegisterStrategy(address indexed collateralType, address indexed strategyHandler);

    event LogMintZrsUsdToStrategy(address indexed collateralType, address indexed strategyHandler, uint256 amount);

    event LogDepositToStrategy(address indexed sender, address indexed collateralType, uint256 amount);

    event LogWithdrawFromStrategy(address indexed sender, address indexed collateralType, uint256 amount);

    function getStrategy(address collateralType) external view returns (address strategyHandler);

    function getStrategyBorrowedUsd(address collateralType) external view returns (uint256);

    function registerStrategy(address strategyHandler, address collateralType, uint128 borrowCap) external;

    function mintUsdToStrategy(address collateralType, uint256 amount) external returns (uint256);

    function depositToStrategy(address collateralType, uint256 assetsAmount, uint256 minSharesAmount) external;

    function withdrawFromStrategy(address collateralType, uint256 sharesAmount, uint256 minAssetsAmount) external;
}
