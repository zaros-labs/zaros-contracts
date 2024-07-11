// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18, unary } from "@prb-math/SD59x18.sol";

// Open Zeppelin dependencies
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

contract PerpMarket_GetOrderFeeUsd_Unit_Test is Base_Test {
    using SafeCast for int256;

    UD60x18 internal mockOpenInterest = ud60x18(1e6);

    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        configureSystemParameters();
        createPerpMarkets();
        changePrank({ msgSender: users.naruto.account });
    }

    function testFuzz_WhenSkewAndSizeDeltaAreGreatherThanZero(
        uint256 marketId,
        uint256 skewAbs,
        uint256 sizeDeltaAbs
    )
        external
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        sizeDeltaAbs = bound({ x: sizeDeltaAbs, min: 1, max: fuzzMarketConfig.maxSkew });

        skewAbs = bound({ x: skewAbs, min: 1, max: fuzzMarketConfig.maxSkew });
        int128 skew = int128(int256(skewAbs));

        perpsEngine.exposed_updateOpenInterest(fuzzMarketConfig.marketId, mockOpenInterest, sd59x18(skew));

        SD59x18 sizeDeltaX18 = sd59x18(int256(sizeDeltaAbs));

        UD60x18 markPriceX18 = ud60x18(fuzzMarketConfig.mockUsdPrice);

        UD60x18 feeUsd = perpsEngine.exposed_getOrderFeeUsd(fuzzMarketConfig.marketId, sizeDeltaX18, markPriceX18);

        UD60x18 expectedFeeUsd =
            markPriceX18.mul(sizeDeltaX18.abs().intoUD60x18()).mul(ud60x18(fuzzMarketConfig.orderFees.takerFee));

        // it should return the taker order fee
        assertEq(expectedFeeUsd.intoUint256(), feeUsd.intoUint256(), "should return the taker order fee");
    }

    function test_WhenSkewAndSizeDeltaAreLessThanZero(
        uint256 marketId,
        uint256 skewAbs,
        uint256 sizeDeltaAbs
    )
        external
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        sizeDeltaAbs = bound({ x: sizeDeltaAbs, min: 1, max: fuzzMarketConfig.maxSkew });

        skewAbs = bound({ x: skewAbs, min: 1, max: fuzzMarketConfig.maxSkew });
        int128 skew = int128(int256(skewAbs));

        perpsEngine.exposed_updateOpenInterest(fuzzMarketConfig.marketId, mockOpenInterest, unary(sd59x18(skew)));

        SD59x18 sizeDeltaX18 = unary(sd59x18(int256(sizeDeltaAbs)));

        UD60x18 markPriceX18 = ud60x18(fuzzMarketConfig.mockUsdPrice);

        UD60x18 feeUsd = perpsEngine.exposed_getOrderFeeUsd(fuzzMarketConfig.marketId, sizeDeltaX18, markPriceX18);

        UD60x18 expectedFeeUsd =
            markPriceX18.mul(sizeDeltaX18.abs().intoUD60x18()).mul(ud60x18(fuzzMarketConfig.orderFees.takerFee));

        // it should return the taker order fee
        assertEq(expectedFeeUsd.intoUint256(), feeUsd.intoUint256(), "should return the taker order fee");
    }

    function test_WhenSkewIsGreatherThanZeroAndSizeDeltaIsLessThanZero(
        uint256 marketId,
        uint256 skewAbs,
        uint256 sizeDeltaAbs
    )
        external
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        sizeDeltaAbs = bound({ x: sizeDeltaAbs, min: 1, max: fuzzMarketConfig.maxSkew });

        skewAbs = bound({ x: skewAbs, min: 1, max: fuzzMarketConfig.maxSkew });
        int128 skew = int128(int256(skewAbs));

        perpsEngine.exposed_updateOpenInterest(fuzzMarketConfig.marketId, mockOpenInterest, sd59x18(skew));

        SD59x18 sizeDeltaX18 = unary(sd59x18(int256(sizeDeltaAbs)));

        UD60x18 markPriceX18 = ud60x18(fuzzMarketConfig.mockUsdPrice);

        UD60x18 feeUsd = perpsEngine.exposed_getOrderFeeUsd(fuzzMarketConfig.marketId, sizeDeltaX18, markPriceX18);

        UD60x18 expectedFeeUsd =
            markPriceX18.mul(sizeDeltaX18.abs().intoUD60x18()).mul(ud60x18(fuzzMarketConfig.orderFees.makerFee));

        // it should return the maker order fee
        assertEq(expectedFeeUsd.intoUint256(), feeUsd.intoUint256(), "should return the maker order fee");
    }

    function test_WhenSkewIsLessThanZeroAndSizeDeltaIsGreatherThanZero(
        uint256 marketId,
        uint256 skewAbs,
        uint256 sizeDeltaAbs
    )
        external
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        sizeDeltaAbs = bound({ x: sizeDeltaAbs, min: 1, max: fuzzMarketConfig.maxSkew });

        skewAbs = bound({ x: skewAbs, min: 1, max: fuzzMarketConfig.maxSkew });
        int128 skew = int128(int256(skewAbs));

        perpsEngine.exposed_updateOpenInterest(fuzzMarketConfig.marketId, mockOpenInterest, unary(sd59x18(skew)));

        SD59x18 sizeDeltaX18 = sd59x18(int256(sizeDeltaAbs));

        UD60x18 markPriceX18 = ud60x18(fuzzMarketConfig.mockUsdPrice);

        UD60x18 feeUsd = perpsEngine.exposed_getOrderFeeUsd(fuzzMarketConfig.marketId, sizeDeltaX18, markPriceX18);

        UD60x18 expectedFeeUsd =
            markPriceX18.mul(sizeDeltaX18.abs().intoUD60x18()).mul(ud60x18(fuzzMarketConfig.orderFees.makerFee));

        // it should return the maker order fee
        assertEq(expectedFeeUsd.intoUint256(), feeUsd.intoUint256(), "should return the maker order fee");
    }
}
