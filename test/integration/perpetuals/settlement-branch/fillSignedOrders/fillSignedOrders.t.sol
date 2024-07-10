// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Constants } from "@zaros/utils/Constants.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { SignedOrder } from "@zaros/perpetuals/leaves/SignedOrder.sol";
import { SettlementConfiguration } from "@zaros/perpetuals/leaves/SettlementConfiguration.sol";
import { Base_Test } from "test/Base.t.sol";

// PRB Math dependencies
import { ud60x18 } from "@prb-math/UD60x18.sol";

contract FillSignedOrders_Integration_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner });
        configureSystemParameters();
        createPerpMarkets();
        changePrank({ msgSender: users.naruto });
    }

    function testFuzz_RevertGiven_TheSenderIsNotTheKeeper(
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        bool isLong,
        uint256 marketId,
        uint256 amountOfOrders
    )
        external
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        initialMarginRate = bound({ x: initialMarginRate, min: fuzzMarketConfig.imr, max: MAX_MARGIN_REQUIREMENTS });
        amountOfOrders = bound({ x: amountOfOrders, min: 1, max: 5 });
        marginValueUsd = bound({
            x: marginValueUsd,
            min: USDC_MIN_DEPOSIT_MARGIN,
            max: convertUd60x18ToTokenAmount(address(usdc), USDC_DEPOSIT_CAP_X18) / amountOfOrders
        });

        SignedOrder.Data[] memory signedOrders = new SignedOrder.Data[](amountOfOrders);

        for (uint256 i = 0; i < amountOfOrders; i++) {
            deal({ token: address(usdc), to: users.naruto, give: marginValueUsd });
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

            uint128 markPrice = perpsEngine.getMarkPrice(
                fuzzMarketConfig.marketId, fuzzMarketConfig.mockUsdPrice, sizeDelta
            ).intoUint128();

            signedOrders[i] = SignedOrder.Data({
                tradingAccountId: tradingAccountId,
                marketId: fuzzMarketConfig.marketId,
                sizeDelta: sizeDelta,
                targetPrice: markPrice,
                nonce: 0,
                shouldIncreaseNonce: false,
                signature: new bytes(0)
            });
        }

        bytes memory mockSignedReport =
            getMockedSignedReport(fuzzMarketConfig.streamId, fuzzMarketConfig.mockUsdPrice);
        address signedOrdersKeeper = SIGNED_ORDERS_KEEPER_ADDRESS;

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Errors.OnlyKeeper.selector, users.naruto, signedOrdersKeeper)
        });
        perpsEngine.fillSignedOrders(fuzzMarketConfig.marketId, signedOrders, mockSignedReport);
    }

    modifier givenTheSenderIsTheKeeper() {
        _;
    }

    function test_RevertWhen_ThePriceDataIsNotValid() external givenTheSenderIsTheKeeper {
        // it should revert
    }

    modifier whenThePriceDataIsValid() {
        _;
    }

    function test_RevertWhen_ASignedOrdersSizeDeltaIsZero()
        external
        givenTheSenderIsTheKeeper
        whenThePriceDataIsValid
    {
        // it should revert
    }

    modifier whenAllSignedOrdersHaveAValidSizeDelta() {
        _;
    }

    function test_RevertWhen_OneOfTheTradingAccountsDoesNotExist()
        external
        givenTheSenderIsTheKeeper
        whenThePriceDataIsValid
        whenAllSignedOrdersHaveAValidSizeDelta
    {
        // it should revert
    }

    modifier whenAllTradingAccountsExist() {
        _;
    }

    function test_RevertWhen_ASignedOrdersMarketIdIsNotEqualToTheProvidedMarketId()
        external
        givenTheSenderIsTheKeeper
        whenThePriceDataIsValid
        whenAllSignedOrdersHaveAValidSizeDelta
        whenAllTradingAccountsExist
    {
        // it should revert
    }

    modifier whenASignedOrdersMarketIdIsEqualToTheProvidedMarketId() {
        _;
    }

    function test_RevertWhen_ASignedOrdersNonceIsNotEqualToTheTradingAccountsNonce()
        external
        givenTheSenderIsTheKeeper
        whenThePriceDataIsValid
        whenAllSignedOrdersHaveAValidSizeDelta
        whenAllTradingAccountsExist
        whenASignedOrdersMarketIdIsEqualToTheProvidedMarketId
    {
        // it should revert
    }

    modifier whenAllSignedOrdersNoncesAreEqualToTheTradingAccountsNonces() {
        _;
    }

    function test_RevertWhen_TheSignedOrdersSignatureCantBeDecoded()
        external
        givenTheSenderIsTheKeeper
        whenThePriceDataIsValid
        whenAllSignedOrdersHaveAValidSizeDelta
        whenAllTradingAccountsExist
        whenASignedOrdersMarketIdIsEqualToTheProvidedMarketId
        whenAllSignedOrdersNoncesAreEqualToTheTradingAccountsNonces
    {
        // it should revert
    }

    modifier whenTheSignedOrdersSignatureCanBeDecoded() {
        _;
    }

    function test_RevertGiven_TheOrdersSignerIsNotTheTradingAccountOwner()
        external
        givenTheSenderIsTheKeeper
        whenThePriceDataIsValid
        whenAllSignedOrdersHaveAValidSizeDelta
        whenAllTradingAccountsExist
        whenASignedOrdersMarketIdIsEqualToTheProvidedMarketId
        whenAllSignedOrdersNoncesAreEqualToTheTradingAccountsNonces
        whenTheSignedOrdersSignatureCanBeDecoded
    {
        // it should revert
    }

    modifier givenTheOrdersSignerIsTheTradingAccountOwner() {
        _;
    }

    function test_WhenASignedOrdersTargetPriceCantBeMatchedWithItsFillPrice()
        external
        givenTheSenderIsTheKeeper
        whenThePriceDataIsValid
        whenAllSignedOrdersHaveAValidSizeDelta
        whenAllTradingAccountsExist
        whenASignedOrdersMarketIdIsEqualToTheProvidedMarketId
        whenAllSignedOrdersNoncesAreEqualToTheTradingAccountsNonces
        whenTheSignedOrdersSignatureCanBeDecoded
        givenTheOrdersSignerIsTheTradingAccountOwner
    {
        // it should not fill that order
    }

    modifier whenAllSignedOrdersTargetPriceCanBeMatchedWithItsFillPrice() {
        _;
    }

    function test_WhenTheSignedOrderShouldIncreaseTheNonce()
        external
        givenTheSenderIsTheKeeper
        whenThePriceDataIsValid
        whenAllSignedOrdersHaveAValidSizeDelta
        whenAllTradingAccountsExist
        whenASignedOrdersMarketIdIsEqualToTheProvidedMarketId
        whenAllSignedOrdersNoncesAreEqualToTheTradingAccountsNonces
        whenTheSignedOrdersSignatureCanBeDecoded
        givenTheOrdersSignerIsTheTradingAccountOwner
        whenAllSignedOrdersTargetPriceCanBeMatchedWithItsFillPrice
    {
        // it should increase the trading account nonce
        // it should fill the signed order
    }

    function test_WhenTheSignedOrderShouldntIncreaseTheNonce()
        external
        givenTheSenderIsTheKeeper
        whenThePriceDataIsValid
        whenAllSignedOrdersHaveAValidSizeDelta
        whenAllTradingAccountsExist
        whenASignedOrdersMarketIdIsEqualToTheProvidedMarketId
        whenAllSignedOrdersNoncesAreEqualToTheTradingAccountsNonces
        whenTheSignedOrdersSignatureCanBeDecoded
        givenTheOrdersSignerIsTheTradingAccountOwner
        whenAllSignedOrdersTargetPriceCanBeMatchedWithItsFillPrice
    {
        // it should not increase the trading account nonce
        // it should fill the signed order
    }
}
