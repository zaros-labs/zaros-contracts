// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

interface IStrategyManagerModule {
    error Zaros_StrategyManagerModule_InvalidSender(address sender, address strategyHandler);

    error Zaros_StrategyManagerModule_StrategyNotRegistered(address collateralType);

    event LogRegisterStrategy(address indexed collateralType, address indexed strategyHandler);

    event LogMintZrsUsdToStrategy(address indexed collateralType, address indexed strategyHandler, uint256 amount);

    event LogDepositToStrategy(address indexed sender, address indexed collateralType, uint256 amount, bytes data);

    event LogWithdrawFromStrategy(address indexed sender, address indexed collateralType, uint256 amount, bytes data);

    function getStrategy(address collateralType) external view returns (address strategyHandler);

    function registerStrategy(address strategyHandler, address collateralType) external;

    function mintZrsUsdToStrategy(address collateralType, uint256 amount) external;

    function depositToStrategy(address collateralType, uint256 amount, bytes calldata data) external;

    function withdrawFromStrategy(address collateralType, uint256 amount, bytes calldata data) external;
}
