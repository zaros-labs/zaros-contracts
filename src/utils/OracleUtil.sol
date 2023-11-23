// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { IAggregatorV3 } from "@zaros/external/chainlink/interfaces/IAggregatorV3.sol";
import { Constants } from "./Constants.sol";

// Open Zeppelin dependencies
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

library OracleUtil {
    using SafeCast for int256;

    /// @notice Thrown when an oracle returns an unexpected, invalid value.
    error InvalidOracleReturn();

    /// @notice Queries the provided Chainlink Price Feed for the margin collateral oracle price.
    /// @param priceFeed The Chainlink Price Feed address.
    /// @return price The price of the given margin collateral type.
    function getPrice(IAggregatorV3 priceFeed) internal view returns (UD60x18 price) {
        uint8 priceDecimals = priceFeed.decimals();
        // should revert if priceDecimals > 18
        if (priceDecimals > Constants.SYSTEM_DECIMALS) {
            revert InvalidOracleReturn();
        }

        try priceFeed.latestRoundData() returns (uint80, int256 answer, uint256, uint256, uint80) {
            price = ud60x18(answer.toUint256() * 10 ** (Constants.SYSTEM_DECIMALS - priceDecimals));
        } catch {
            revert InvalidOracleReturn();
        }
    }
}
