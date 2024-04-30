// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

library FeeRecipients {
    struct Data {
        address marginCollateralRecipient;
        address orderFeeRecipient;
        address settlementFeeRecipient;
    }
}
