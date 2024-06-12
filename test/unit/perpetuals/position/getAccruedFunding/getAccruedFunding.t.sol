// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { Base_Test } from "test/Base.t.sol";
import { Position } from "@zaros/perpetuals/leaves/Position.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18, unary } from "@prb-math/SD59x18.sol";

// Open Zeppelin dependencies
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

contract Position_GetAccruedFunding_Unit_Test is Base_Test {
    using SafeCast for int256;

    function setUp() public override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner });
        configureSystemParameters();
        createPerpMarkets();
    }

    function testFuzz_WhenGetAccruedFundingIsCalled(
        uint256 marketId,
        int128 fundingFeePerUnit,
        int128 lastInteractionFundingFeePerUnit,
        bool isLong
    )
        external
    {
        changePrank({ msgSender: users.naruto });

        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        SD59x18 sizeDeltaAbs = ud60x18(fuzzMarketConfig.minTradeSize).intoSD59x18();
        int128 size = isLong ? sizeDeltaAbs.intoInt256().toInt128() : unary(sizeDeltaAbs).intoInt256().toInt128();

        Position.Data memory mockPosition = Position.Data({
            size: size,
            lastInteractionPrice: uint128(fuzzMarketConfig.mockUsdPrice),
            lastInteractionFundingFeePerUnit: lastInteractionFundingFeePerUnit
        });

        uint128 tradingAccountId = perpsEngine.createTradingAccount();

        perpsEngine.exposed_update(tradingAccountId, fuzzMarketConfig.marketId, mockPosition);

        SD59x18 fundingFeePerUnitX18 = sd59x18(fundingFeePerUnit);
        SD59x18 netFundingFeePerUnit =
            fundingFeePerUnitX18.sub(sd59x18(mockPosition.lastInteractionFundingFeePerUnit));
        SD59x18 expectedAccruedFundingUsdX18 = sd59x18(mockPosition.size).mul(netFundingFeePerUnit);

        SD59x18 accruedFundingUsdX18 =
            perpsEngine.exposed_getAccruedFunding(tradingAccountId, fuzzMarketConfig.marketId, fundingFeePerUnitX18);

        // it should return the accrued funding usd
        assertEq(
            expectedAccruedFundingUsdX18.intoInt256(),
            accruedFundingUsdX18.intoInt256(),
            "Invalid accrued funding usd"
        );
    }
}
