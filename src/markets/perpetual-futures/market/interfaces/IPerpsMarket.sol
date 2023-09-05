// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { IOrderModule } from "./IOrderModule.sol";
import { Position } from "../storage/Position.sol";

// PRB Math dependencies
import { UD60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18 } from "@prb-math/SD59x18.sol";

interface IPerpsMarket is IOrderModule {
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function skew() external view returns (SD59x18);

    function totalOpenInterest() external view returns (UD60x18);

    function indexPrice() external view returns (UD60x18);

    function oracle() external view returns (address);

    function fundingRate() external view returns (SD59x18);

    function fundingVelocity() external view returns (SD59x18);

    function getOpenPositionData(uint256 accountId)
        external
        view
        returns (
            UD60x18 notionalValue,
            SD59x18 size,
            SD59x18 pnl,
            SD59x18 accruedFunding,
            SD59x18 netFundingPerUnit,
            SD59x18 nextFunding
        );

    function setPerpsManager(address perpsManager) external;
}
