// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

interface IStrategyManagerModule {
    event LogRegisterStrategy(address indexed collateralType, address indexed strategy);

    function getStrategy(address collateralType) external view returns (address strategy);

    function registerStrategy(address strategy, address collateralType) external;

    function mintZrsUsdToStrategy(address collateralType, uint256 amount) external;

    function depositToStrategy(address collateralType, uint256 amount, bytes calldata data) external;

    function withdrawFromStrategy(address collateralType, uint256 amount, bytes calldata data) external;
}
