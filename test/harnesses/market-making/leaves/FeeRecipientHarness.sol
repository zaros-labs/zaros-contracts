// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { FeeRecipient } from "@zaros/market-making/leaves/FeeRecipient.sol";

contract FeeRecipientHarness {
    function exposed_FeeRecipient_load(address recipient) external pure returns (FeeRecipient.Data memory) {
        FeeRecipient.Data memory feeRecipientData = FeeRecipient.load(recipient);
        return feeRecipientData;
    }

    function workaround_setFeeRecipientShares(address recipient, uint256 shares) external {
        FeeRecipient.Data storage feeRecipientData = FeeRecipient.load(recipient);
        feeRecipientData.share = shares;
    }
}
