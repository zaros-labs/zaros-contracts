// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";

// PRB Math dependencies
import { SD59x18, sd59x18 } from "@prb-math/SD59x18.sol";

contract UpdateActiveMarkets_Unit_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();

        changePrank({ msgSender: users.owner.account });

        configureSystemParameters();

        createPerpMarkets();

        changePrank({ msgSender: users.naruto.account });
    }

    modifier whenThisIsANewPosition() {
        _;
    }

    function testFuzz_WhenThereHasBeenNoNewMarketOrderEnteredNorApreviouslyActiveMarketExited(
        uint256 marginValueUsd,
        uint256 marketId
    )
        external
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        marginValueUsd = bound({
            x: marginValueUsd,
            min: USDC_MIN_DEPOSIT_MARGIN,
            max: convertUd60x18ToTokenAmount(address(usdc), USDC_DEPOSIT_CAP_X18)
        });

        SD59x18 oldPositionSize;
        SD59x18 newPositionSize;

        deal({ token: address(usdc), to: users.naruto.account, give: marginValueUsd });

        // create trading account
        uint128 tradingAccountId = createAccountAndDeposit(marginValueUsd, address(usdc));

        // it should not do anything
        perpsEngine.exposed_updateActiveMarkets(
            tradingAccountId, fuzzMarketConfig.marketId, oldPositionSize, newPositionSize
        );
    }

    function testFuzz_WhenThisAccountHasNoOtherActivePositions(
        uint256 marginValueUsd,
        uint256 marketId,
        uint256 oldPositionSize,
        uint256 newPositionSize
    )
        external
        whenThisIsANewPosition
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        marginValueUsd = bound({
            x: marginValueUsd,
            min: USDC_MIN_DEPOSIT_MARGIN,
            max: convertUd60x18ToTokenAmount(address(usdc), USDC_DEPOSIT_CAP_X18)
        });

        newPositionSize = bound({
            x: newPositionSize,
            min: USDC_MIN_DEPOSIT_MARGIN,
            max: convertUd60x18ToTokenAmount(address(usdc), USDC_DEPOSIT_CAP_X18)
        });

        oldPositionSize = bound({
            x: oldPositionSize,
            min: USDC_MIN_DEPOSIT_MARGIN,
            max: convertUd60x18ToTokenAmount(address(usdc), USDC_DEPOSIT_CAP_X18)
        });

        SD59x18 oldPositionSizeSD59x18 = sd59x18(int256(0));

        SD59x18 newPositionSizeSD59x18 = sd59x18(int256(newPositionSize));

        deal({ token: address(usdc), to: users.naruto.account, give: marginValueUsd });

        // create trading account
        uint128 tradingAccountId = createAccountAndDeposit(marginValueUsd, address(usdc));

        // it should add this market id as active for this account
        perpsEngine.exposed_updateActiveMarkets(
            tradingAccountId, fuzzMarketConfig.marketId, oldPositionSizeSD59x18, newPositionSizeSD59x18
        );
    }

    function testFuzz_WhenThisAccountHasOtherActivePositions(
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        bool isLong,
        uint256 marketId,
        uint256 oldPositionSize,
        uint256 newPositionSize
    )
        external
        whenThisIsANewPosition
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);
        initialMarginRate = bound({ x: initialMarginRate, min: fuzzMarketConfig.imr, max: MAX_MARGIN_REQUIREMENTS });

        marginValueUsd = bound({
            x: marginValueUsd,
            min: USDC_MIN_DEPOSIT_MARGIN,
            max: convertUd60x18ToTokenAmount(address(usdc), USDC_DEPOSIT_CAP_X18)
        });

        newPositionSize = bound({
            x: newPositionSize,
            min: USDC_MIN_DEPOSIT_MARGIN,
            max: convertUd60x18ToTokenAmount(address(usdc), USDC_DEPOSIT_CAP_X18)
        });

        oldPositionSize = bound({
            x: oldPositionSize,
            min: USDC_MIN_DEPOSIT_MARGIN,
            max: convertUd60x18ToTokenAmount(address(usdc), USDC_DEPOSIT_CAP_X18)
        });

        SD59x18 oldPositionSizeSD59x18 = sd59x18(int256(0));

        SD59x18 newPositionSizeSD59x18 = sd59x18(int256(newPositionSize));

        deal({ token: address(usdc), to: users.naruto.account, give: marginValueUsd });

        // create trading account
        uint128 tradingAccountId = createAccountAndDeposit(marginValueUsd, address(usdc));

        // open an existing position to enter the if check
        openPosition(fuzzMarketConfig, tradingAccountId, initialMarginRate, marginValueUsd, isLong);

        // it should add this market id as active for this account
        perpsEngine.exposed_updateActiveMarkets(
            tradingAccountId, fuzzMarketConfig.marketId, oldPositionSizeSD59x18, newPositionSizeSD59x18
        );
    }

    modifier whenTheExistingPositionWasClosed() {
        _;
    }

    function testFuzz_WhenTheAccountHasNoMoreActiveMarkets(
        uint256 marginValueUsd,
        uint256 marketId,
        uint256 oldPositionSize,
        uint256 newPositionSize
    )
        external
        whenTheExistingPositionWasClosed
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        marginValueUsd = bound({
            x: marginValueUsd,
            min: USDC_MIN_DEPOSIT_MARGIN,
            max: convertUd60x18ToTokenAmount(address(usdc), USDC_DEPOSIT_CAP_X18)
        });

        newPositionSize = bound({
            x: newPositionSize,
            min: USDC_MIN_DEPOSIT_MARGIN,
            max: convertUd60x18ToTokenAmount(address(usdc), USDC_DEPOSIT_CAP_X18)
        });

        oldPositionSize = bound({
            x: oldPositionSize,
            min: USDC_MIN_DEPOSIT_MARGIN,
            max: convertUd60x18ToTokenAmount(address(usdc), USDC_DEPOSIT_CAP_X18)
        });

        SD59x18 oldPositionSizeSD59x18 = sd59x18(int256(oldPositionSize));

        SD59x18 newPositionSizeSD59x18 = sd59x18(int256(0));

        deal({ token: address(usdc), to: users.naruto.account, give: marginValueUsd });

        // create trading account
        uint128 tradingAccountId = createAccountAndDeposit(marginValueUsd, address(usdc));

        // it should remove the account from active accounts in global config
        perpsEngine.exposed_updateActiveMarkets(
            tradingAccountId, fuzzMarketConfig.marketId, oldPositionSizeSD59x18, newPositionSizeSD59x18
        );
    }

    function testFuzz_WhenTheAccountHasActiveMarkets(
        uint256 marginValueUsd,
        uint256 marketId,
        uint256 newMarketId,
        uint256 oldPositionSize,
        uint256 newPositionSize
    )
        external
        whenTheExistingPositionWasClosed
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        marginValueUsd = bound({
            x: marginValueUsd,
            min: USDC_MIN_DEPOSIT_MARGIN,
            max: convertUd60x18ToTokenAmount(address(usdc), USDC_DEPOSIT_CAP_X18)
        });

        newPositionSize = bound({
            x: newPositionSize,
            min: USDC_MIN_DEPOSIT_MARGIN,
            max: convertUd60x18ToTokenAmount(address(usdc), USDC_DEPOSIT_CAP_X18)
        });

        oldPositionSize = bound({
            x: oldPositionSize,
            min: USDC_MIN_DEPOSIT_MARGIN,
            max: convertUd60x18ToTokenAmount(address(usdc), USDC_DEPOSIT_CAP_X18)
        });

        SD59x18 oldPositionSizeSD59x18 = sd59x18(int256(oldPositionSize));

        SD59x18 newPositionSizeSD59x18 = sd59x18(int256(0));

        deal({ token: address(usdc), to: users.naruto.account, give: marginValueUsd });

        // create trading account
        uint128 tradingAccountId = createAccountAndDeposit(marginValueUsd, address(usdc));

        MarketConfig memory newFuzzMarketConfigMarketId = getFuzzMarketConfig(newMarketId);

        // prevent marketId collisions
        if (fuzzMarketConfig.marketId == newFuzzMarketConfigMarketId.marketId) {
            if (fuzzMarketConfig.marketId == INITIAL_MARKET_ID) {
                newFuzzMarketConfigMarketId.marketId += 1;
            } else if (fuzzMarketConfig.marketId == FINAL_MARKET_ID) {
                newFuzzMarketConfigMarketId.marketId -= 1;
            }
        }

        SD59x18 oldMarketIdPositionSizeSD59x18 = sd59x18(int256(0));

        SD59x18 newMarketIdPositionSizeSD59x18 = sd59x18(int256(100_000));

        // add another market id to skip one of the if checks
        perpsEngine.exposed_updateActiveMarkets(
            tradingAccountId,
            newFuzzMarketConfigMarketId.marketId,
            oldMarketIdPositionSizeSD59x18,
            newMarketIdPositionSizeSD59x18
        );

        // it should remove this market as active for this account
        perpsEngine.exposed_updateActiveMarkets(
            tradingAccountId, fuzzMarketConfig.marketId, oldPositionSizeSD59x18, newPositionSizeSD59x18
        );
    }
}
