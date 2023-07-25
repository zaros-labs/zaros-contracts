// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

library Order {
    struct Data {
        address account;
        address collateralType;
        uint256 marginAmount;
        int256 sizeDelta;
        uint184 desiredPrice;
        uint64 deadline;
        bool filled;
    }
}
