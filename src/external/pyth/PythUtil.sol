// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

// Zaros dependencies
import { IPyth } from "@zaros/external/pyth/interfaces/IPyth.sol";

// Open Zeppelin dependencies
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18 } from "@prb-math/SD59x18.sol";

library PythUtil {
    using SafeCast for int256;

    // A price with a degree of uncertainty, represented as a price +- a confidence interval.
    //
    // The confidence interval roughly corresponds to the standard error of a normal distribution.
    // Both the price and confidence are stored in a fixed-point numeric representation,
    // `x * (10^expo)`, where `expo` is the exponent.
    //
    // Please refer to the documentation at https://docs.pyth.network/consumers/best-practices for how
    // to how this price safely.
    struct Price {
        // Price
        int64 price;
        // Confidence interval around the price
        uint64 conf;
        // Price exponent
        int32 expo;
        // Unix timestamp describing when the price was published
        uint256 publishTime;
    }

    /// @param pyth The Pyth Price Feed address.
    /// @param priceFeedId The price feed id.
    struct GetPriceParams {
        IPyth pyth;
        bytes32 priceFeedId;
    }

    /// @notice Queries the provided Chainlink Price Feed for the margin collateral oracle price.
    /// @param params The GetPriceParams struct.
    /// @return price in zaros internal precision
    function getPrice(GetPriceParams memory params) internal view returns (UD60x18 price) {
        Price memory pythData = params.pyth.getPriceUnsafe(params.priceFeedId);

        price = ud60x18(
            uint256(int256(pythData.price)) * 10 ** (18 - (uint256((sd59x18(pythData.expo).abs().intoInt256())) - 1))
        );
    }
}
