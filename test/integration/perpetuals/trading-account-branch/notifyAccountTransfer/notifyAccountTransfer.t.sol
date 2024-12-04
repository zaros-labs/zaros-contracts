// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { Base_Test } from "test/Base.t.sol";
import { OrderBranch } from "@zaros/perpetuals/branches/OrderBranch.sol";
import { SettlementConfiguration } from "@zaros/perpetuals/leaves/SettlementConfiguration.sol";
import { MarketOrder } from "@zaros/perpetuals/leaves/MarketOrder.sol";
import { TradingAccountBranch } from "@zaros/perpetuals/branches/TradingAccountBranch.sol";

// PRB Math dependencies
import { ud60x18 } from "@prb-math/UD60x18.sol";

contract NotifyAccountTransfer_Integration_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        configureSystemParameters();
        createPerpMarkets();
        changePrank({ msgSender: users.naruto.account });
    }

    function test_RevertGiven_TheSenderIsNotTheAccountNftContract() external {
        uint128 tradingAccountId = perpsEngine.createTradingAccount(bytes(""), false);

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Errors.OnlyTradingAccountToken.selector, users.naruto.account)
        });

        perpsEngine.notifyAccountTransfer(users.madara.account, tradingAccountId);
    }

    function testFuzz_GivenTheSenderIsTheAccountNftContract(uint256 marginValueUsd) external {
       marginValueUsd = bound({
            x: marginValueUsd,
            min: WSTETH_MIN_DEPOSIT_MARGIN,
            max: convertUd60x18ToTokenAmount(address(wstEth), WSTETH_DEPOSIT_CAP_X18)
        });
        deal({ token: address(wstEth), to: users.naruto.account, give: marginValueUsd });

        uint128 tradingAccountId = createAccountAndDeposit(marginValueUsd, address(wstEth));

        changePrank({ msgSender: address(tradingAccountToken) });

        // it should transfer the trading account token
        perpsEngine.notifyAccountTransfer(users.madara.account, tradingAccountId);

        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                Errors.AccountPermissionDenied.selector, tradingAccountId, users.naruto.account
            )
        });

        // old user cannot withdraw
        changePrank({ msgSender: users.naruto.account });
        perpsEngine.withdrawMargin(tradingAccountId, address(wstEth), marginValueUsd);

        // new user can withdraw
        changePrank({ msgSender: users.madara.account });
        perpsEngine.withdrawMargin(tradingAccountId, address(wstEth), marginValueUsd);
    }

    function test_RevertGiven_ThePreviousOwnerHasPendingMarketOrderWithMinimumLifeTimeNotPassed(
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        bool isLong,
        uint256 marketId
    ) 
        external 
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        initialMarginRate =
            bound({ x: initialMarginRate, min: fuzzMarketConfig.marginRequirements, max: MAX_MARGIN_REQUIREMENTS });
        marginValueUsd = bound({
            x: marginValueUsd,
            min: USDC_MIN_DEPOSIT_MARGIN,
            max: convertUd60x18ToTokenAmount(address(usdc), USDC_DEPOSIT_CAP_X18)
        });

        deal({ token: address(usdc), to: users.naruto.account, give: marginValueUsd });

        uint128 tradingAccountId = createAccountAndDeposit(marginValueUsd, address(usdc));
         int128 sizeDelta = fuzzOrderSizeDelta(
            FuzzOrderSizeDeltaParams({
                tradingAccountId: tradingAccountId,
                marketId: fuzzMarketConfig.marketId,
                settlementConfigurationId: SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID,
                initialMarginRate: ud60x18(initialMarginRate),
                marginValueUsd: ud60x18(marginValueUsd),
                maxSkew: ud60x18(fuzzMarketConfig.maxSkew),
                minTradeSize: ud60x18(fuzzMarketConfig.minTradeSize),
                price: ud60x18(fuzzMarketConfig.mockUsdPrice),
                isLong: isLong,
                shouldDiscountFees: true
            })
        );

        perpsEngine.createMarketOrder(
            OrderBranch.CreateMarketOrderParams({
                tradingAccountId: tradingAccountId,
                marketId: fuzzMarketConfig.marketId,
                sizeDelta: sizeDelta
            })
        );
        
        changePrank({ msgSender: address(tradingAccountToken) });

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Errors.MarketOrderStillPending.selector, block.timestamp)
        });

        // transfer the trading account token
        perpsEngine.notifyAccountTransfer(users.madara.account, tradingAccountId);  
    }

    function test_GivenThePreviousOwnerHasPendingMarketOrderWithMinimumLifeTimePassed(
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        bool isLong,
        uint256 marketId
    ) 
        external 
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        initialMarginRate =
            bound({ x: initialMarginRate, min: fuzzMarketConfig.marginRequirements, max: MAX_MARGIN_REQUIREMENTS });
        marginValueUsd = bound({
            x: marginValueUsd,
            min: USDC_MIN_DEPOSIT_MARGIN,
            max: convertUd60x18ToTokenAmount(address(usdc), USDC_DEPOSIT_CAP_X18)
        });

        deal({ token: address(usdc), to: users.naruto.account, give: marginValueUsd });

        uint128 tradingAccountId = createAccountAndDeposit(marginValueUsd, address(usdc));
         int128 sizeDelta = fuzzOrderSizeDelta(
            FuzzOrderSizeDeltaParams({
                tradingAccountId: tradingAccountId,
                marketId: fuzzMarketConfig.marketId,
                settlementConfigurationId: SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID,
                initialMarginRate: ud60x18(initialMarginRate),
                marginValueUsd: ud60x18(marginValueUsd),
                maxSkew: ud60x18(fuzzMarketConfig.maxSkew),
                minTradeSize: ud60x18(fuzzMarketConfig.minTradeSize),
                price: ud60x18(fuzzMarketConfig.mockUsdPrice),
                isLong: isLong,
                shouldDiscountFees: true
            })
        );

        perpsEngine.createMarketOrder(
            OrderBranch.CreateMarketOrderParams({
                tradingAccountId: tradingAccountId,
                marketId: fuzzMarketConfig.marketId,
                sizeDelta: sizeDelta
            })
        );

        changePrank({ msgSender: users.owner.account });
        perpsEngine.configureSystemParameters({
            maxPositionsPerAccount: MAX_POSITIONS_PER_ACCOUNT,
            marketOrderMinLifetime: 0,
            liquidationFeeUsdX18: LIQUIDATION_FEE_USD,
            marginCollateralRecipient: feeRecipients.marginCollateralRecipient,
            orderFeeRecipient: feeRecipients.orderFeeRecipient,
            settlementFeeRecipient: feeRecipients.settlementFeeRecipient,
            liquidationFeeRecipient: users.liquidationFeeRecipient.account,
            marketMakingEngine: address(marketMakingEngine),
            maxVerificationDelay: MAX_VERIFICATION_DELAY
        });
        
        changePrank({ msgSender: address(tradingAccountToken) });

        // transfer the trading account
        perpsEngine.notifyAccountTransfer(users.madara.account, tradingAccountId);

        MarketOrder.Data memory marketOrder = perpsEngine.getActiveMarketOrder(tradingAccountId);

        // it should cancel the active market order
        assertEq(marketOrder.marketId, 0);
        assertEq(marketOrder.sizeDelta, 0);
        assertEq(marketOrder.timestamp, 0);
        
        // new user can withdraw
        changePrank({ msgSender: users.madara.account });
        perpsEngine.withdrawMargin(tradingAccountId, address(usdc), marginValueUsd);
    }
}
