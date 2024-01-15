// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { MockPriceFeed } from "test/mocks/MockPriceFeed.sol";

struct Users {
    // Default owner for all Zaros contracts.
    address payable owner;
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
    MockPriceFeed mockUsdcUsdPriceAdapter;
    MockPriceFeed mockWstEthUsdPriceAdapter;
}
