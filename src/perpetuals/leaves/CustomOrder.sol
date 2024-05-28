// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

library CustomOrder {
    struct Data {
        uint128 tradingAccountId;
        int128 sizeDelta;
        uint256 targetPrice;
        bytes signature;
    }
}
