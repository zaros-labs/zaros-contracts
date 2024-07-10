pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";

contract FillSignedOrders_Integration_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner });
        configureSystemParameters();
        createPerpMarkets();
        changePrank({ msgSender: users.naruto });
    }

    function test_RevertGiven_TheSenderIsNotTheKeeper() external {
        // it should revert
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
