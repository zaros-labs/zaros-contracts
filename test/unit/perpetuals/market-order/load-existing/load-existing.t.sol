// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";
import { MarketOrder } from "@zaros/perpetuals/leaves/MarketOrder.sol";

contract LoadExisting_Unit_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        configureSystemParameters();
        createPerpMarkets();
        changePrank({ msgSender: users.naruto.account });
    }

    function test_GivenYouHaveAMarketOrder(
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        uint256 marketId,
        bool isLong
    )
        external
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        initialMarginRate = bound({ x: initialMarginRate, min: fuzzMarketConfig.imr, max: MAX_MARGIN_REQUIREMENTS });

        marginValueUsd = bound({
            x: marginValueUsd,
            min: USDC_MIN_DEPOSIT_MARGIN,
            max: convertUd60x18ToTokenAmount(address(usdc), USDC_DEPOSIT_CAP_X18)
        });

        deal({ token: address(usdc), to: users.naruto.account, give: marginValueUsd });

        uint128 tradingAccountId = createAccountAndDeposit(marginValueUsd, address(usdc));

        openPosition({
            fuzzMarketConfig: fuzzMarketConfig,
            tradingAccountId: tradingAccountId,
            initialMarginRate: initialMarginRate,
            marginValueUsd: marginValueUsd,
            isLong: isLong
        });

        // it should load the market order
        MarketOrder.Data memory marketOrder = perpsEngine.exposed_MarketOrder_loadExisting(tradingAccountId);
    }

    function test_RevertGiven_YouDoNotHaveAMarketOrder() external {
        // it should revert
    }
}
