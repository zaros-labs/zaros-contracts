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

contract Position_Update_Unit_Test is Base_Test {
    using SafeCast for int256;

    function setUp() public override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner });
        configureSystemParameters();
        createPerpMarkets();
    }

    function testFuzz_WhenUpdateIsCalled(
        uint256 marketId,
        int128 lastInteractionFundingFeePerUnit,
        bool isLong
    )
        external
    {
        changePrank({ msgSender: users.naruto });

        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        SD59x18 sizeDeltaAbs = ud60x18(fuzzMarketConfig.minTradeSize).intoSD59x18();
        int128 size = isLong ? sizeDeltaAbs.intoInt256().toInt128() : unary(sizeDeltaAbs).intoInt256().toInt128();

        uint128 tradingAccountId = perpsEngine.createTradingAccount();

        Position.Data memory mockPosition = Position.Data({
            size: size,
            lastInteractionPrice: uint128(fuzzMarketConfig.mockUsdPrice),
            lastInteractionFundingFeePerUnit: lastInteractionFundingFeePerUnit
        });

        perpsEngine.exposed_update(tradingAccountId, fuzzMarketConfig.marketId, mockPosition);

        Position.Data memory position = perpsEngine.exposed_Position_load(tradingAccountId, fuzzMarketConfig.marketId);

        // it should update the size
        assertEq(position.size, mockPosition.size, "Position size not updated");

        // it should update the lastInteractionPrice
        assertEq(
            position.lastInteractionPrice,
            mockPosition.lastInteractionPrice,
            "Position lastInteractionPrice not updated"
        );

        // it should update the lastInteractionFundingFeePerUnit
        assertEq(
            position.lastInteractionFundingFeePerUnit,
            mockPosition.lastInteractionFundingFeePerUnit,
            "Position lastInteractionFundingFeePerUnit not updated"
        );
    }
}
