// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { Base_Integration_Shared_Test } from "test/integration/shared/BaseIntegration.t.sol";
import { IPerpsEngine } from "@zaros/perpetuals/PerpsEngine.sol";
import { MarketOrderKeeper } from "@zaros/external/chainlink/keepers/market-order/MarketOrderKeeper.sol";

contract MarketOrderKeeperGetConfig_Integration_Test is Base_Integration_Shared_Test {
    function setUp() public override {
        Base_Integration_Shared_Test.setUp();
        changePrank({ msgSender: users.owner });
        configureSystemParameters();

        createPerpMarkets();

        changePrank({ msgSender: users.naruto });
    }

    modifier givenInitializeContract() {
        _;
    }

    function testFuzz_WhenCallGetConfigFunction(uint256 marketId) external givenInitializeContract {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);
        address settlementFeeRecipient = address(0x20);
        address marketOrderKeeperImplementation = address(new MarketOrderKeeper());

        address marketOrderKeeper = deployMarketOrderKeeper(
            fuzzMarketConfig.marketId,
            users.owner,
            perpsEngine,
            settlementFeeRecipient,
            marketOrderKeeperImplementation
        );

        (address keeperOwner,, address perpsEngine, address feeRecipient, uint256 marketIdConfig) =
            MarketOrderKeeper(marketOrderKeeper).getConfig();

        // it should return keeper owner
        assertEq(users.owner, keeperOwner, "keeper owner is not correct");

        // it should return address of perps engine
        assertEq(address(perpsEngine), perpsEngine, "perps engine is not correct");

        // it should return address of fee recipient
        assertEq(settlementFeeRecipient, feeRecipient, "fee recipient is not correct");

        // it should return market id
        assertEq(fuzzMarketConfig.marketId, marketIdConfig, "market id is not correct");
    }
}
