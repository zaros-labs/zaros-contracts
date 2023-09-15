// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { Position } from "../storage/Position.sol";

// PRB Math dependencies
import { UD60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18 } from "@prb-math/SD59x18.sol";

interface IPerpsEngine {
    function name(uint128 marketId) external view returns (string memory);

    function symbol(uint128 marketId) external view returns (string memory);

    function skew(uint128 marketId) external view returns (SD59x18);

    function totalOpenInterest(uint128 marketId) external view returns (UD60x18);

    function indexPrice(uint128 marketId) external view returns (UD60x18);

    function priceFeed(uint128 marketId) external view returns (address);

    function fundingRate(uint128 marketId) external view returns (SD59x18);

    function fundingVelocity(uint128 marketId) external view returns (SD59x18);

    function getOpenPositionData(
        uint256 accountId,
        uint128 marketId
    )
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
}
