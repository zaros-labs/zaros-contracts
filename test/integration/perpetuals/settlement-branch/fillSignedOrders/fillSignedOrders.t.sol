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

    function test_RevertWhen_OneOfTheTradingAccountsDoesNotExist() external {
        // it should revert
    }

    modifier whenAllTradingAccountsExist() {
        _;
    }

    function test_RevertWhen_ASignedOrdersNonceIsNotEqualToTheTradingAccountsNonce()
        external
        whenAllTradingAccountsExist
    {
        // it should revert
    }

    modifier whenAllSignedOrdersNonceAreEqualToTheTradingAccountsNonces() {
        _;
    }

    function test_RevertWhen_TheSignedOrdersSignatureCantBeDecoded()
        external
        whenAllTradingAccountsExist
        whenAllSignedOrdersNonceAreEqualToTheTradingAccountsNonces
    {
        // it should revert
    }

    modifier whenTheSignedOrdersSignatureCanBeDecoded() {
        _;
    }

    function test_RevertGiven_TheOrdersSignerIsNotTheTradingAccountOwner()
        external
        whenAllTradingAccountsExist
        whenAllSignedOrdersNonceAreEqualToTheTradingAccountsNonces
        whenTheSignedOrdersSignatureCanBeDecoded
    {
        // it should revert
    }

    modifier givenTheOrdersSignerIsTheTradingAccountOwner() {
        _;
    }

    function test_WhenTheSignedOrderShouldIncreaseTheNonce()
        external
        whenAllTradingAccountsExist
        whenAllSignedOrdersNonceAreEqualToTheTradingAccountsNonces
        whenTheSignedOrdersSignatureCanBeDecoded
        givenTheOrdersSignerIsTheTradingAccountOwner
    {
        // it should increase the trading account nonce
        // it should fill the signed order
    }

    function test_WhenTheSignedOrderShouldntIncreaseTheNonce()
        external
        whenAllTradingAccountsExist
        whenAllSignedOrdersNonceAreEqualToTheTradingAccountsNonces
        whenTheSignedOrdersSignatureCanBeDecoded
        givenTheOrdersSignerIsTheTradingAccountOwner
    {
        // it should not increase the trading account nonce
        // it should fill the signed order
    }
}
