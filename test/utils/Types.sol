// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { MockPriceFeed } from "test/mocks/MockPriceFeed.sol";

struct Users {
    // Default owner for all Zaros contracts.
    address payable owner;
    // User that is paid settlement fees.
    address payable settlementFeeRecipient;
    // Impartial user 1.
    address payable naruto;
    // Impartial user 2.
    address payable sasuke;
    // Impartial user 3.
    address payable sakura;
    // Malicious user.
    address payable madara;
}

struct MockPriceAdapters {
    MockPriceFeed mockBtcUsdPriceAdapter;
    MockPriceFeed mockEthUsdPriceAdapter;
    MockPriceFeed mockLinkUsdPriceAdapter;
    MockPriceFeed mockUsdcUsdPriceAdapter;
    MockPriceFeed mockWstEthUsdPriceAdapter;
}
