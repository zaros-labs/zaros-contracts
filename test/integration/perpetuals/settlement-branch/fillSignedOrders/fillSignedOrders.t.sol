// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { IVerifierProxy } from "@zaros/external/chainlink/interfaces/IVerifierProxy.sol";
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
                salt: bytes32(0),
                v: 0,
                r: bytes32(0),
                s: bytes32(0)
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

    function testFuzz_RevertWhen_ThePriceDataIsNotValid(
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        bool isLong,
        uint256 marketId,
        uint256 amountOfOrders
    )
        external
        givenTheSenderIsTheKeeper
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
                salt: bytes32(0),
                v: 0,
                r: bytes32(0),
                s: bytes32(0)
            });
        }

        bytes memory mockSignedReport =
            getMockedSignedReport(fuzzMarketConfig.streamId, fuzzMarketConfig.mockUsdPrice);
        address signedOrdersKeeper = SIGNED_ORDERS_KEEPER_ADDRESS;

        SettlementConfiguration.DataStreamsStrategy memory signedOrdersConfigurationData = SettlementConfiguration
            .DataStreamsStrategy({ chainlinkVerifier: IVerifierProxy(address(1)), streamId: fuzzMarketConfig.streamId });
        SettlementConfiguration.Data memory signedOrdersConfiguration = SettlementConfiguration.Data({
            strategy: SettlementConfiguration.Strategy.DATA_STREAMS_DEFAULT,
            isEnabled: true,
            fee: DEFAULT_SETTLEMENT_FEE,
            keeper: signedOrdersKeeper,
            data: abi.encode(signedOrdersConfigurationData)
        });

        changePrank({ msgSender: users.owner });

        perpsEngine.updateSettlementConfiguration({
            marketId: fuzzMarketConfig.marketId,
            settlementConfigurationId: SettlementConfiguration.SIGNED_ORDERS_CONFIGURATION_ID,
            newSettlementConfiguration: signedOrdersConfiguration
        });

        changePrank({ msgSender: signedOrdersKeeper });
        // it should revert
        vm.expectRevert();

        perpsEngine.fillSignedOrders(fuzzMarketConfig.marketId, signedOrders, mockSignedReport);
    }

    modifier whenThePriceDataIsValid() {
        _;
    }

    function testFuzz_RevertWhen_ASignedOrdersSizeDeltaIsZero(
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        bool isLong,
        uint256 marketId,
        uint256 amountOfOrders
    )
        external
        givenTheSenderIsTheKeeper
        whenThePriceDataIsValid
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        initialMarginRate = bound({ x: initialMarginRate, min: fuzzMarketConfig.imr, max: MAX_MARGIN_REQUIREMENTS });
        amountOfOrders = bound({ x: amountOfOrders, min: 1, max: 5 });
        marginValueUsd = bound({
            x: marginValueUsd,
            min: USDC_MIN_DEPOSIT_MARGIN,
            max: convertUd60x18ToTokenAmount(address(usdc), USDC_DEPOSIT_CAP_X18) / amountOfOrders
        });

        SignedOrder.Data[] memory signedOrders = new SignedOrder.Data[](amountOfOrders + 1);

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
                salt: bytes32(0),
                v: 0,
                r: bytes32(0),
                s: bytes32(0)
            });
        }
        signedOrders[signedOrders.length - 1] = SignedOrder.Data({
            tradingAccountId: 1,
            marketId: 0,
            sizeDelta: 0,
            targetPrice: 0,
            nonce: 0,
            shouldIncreaseNonce: false,
            salt: bytes32(0),
            v: 0,
            r: bytes32(0),
            s: bytes32(0)
        });

        bytes memory mockSignedReport =
            getMockedSignedReport(fuzzMarketConfig.streamId, fuzzMarketConfig.mockUsdPrice);
        address signedOrdersKeeper = SIGNED_ORDERS_KEEPER_ADDRESS;

        changePrank({ msgSender: signedOrdersKeeper });
        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "signedOrder.sizeDelta") });

        perpsEngine.fillSignedOrders(fuzzMarketConfig.marketId, signedOrders, mockSignedReport);
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
