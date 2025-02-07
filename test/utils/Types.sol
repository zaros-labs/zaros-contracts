// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

struct Users {
    // Default owner for all Zaros contracts.
    User owner;
    // Default forwarder for Chainlink Automation-powered keepers
    User keepersForwarder;
    // Address that receives vault deposit/redeem fees
    User vaultFeeRecipient;
    // Impartial user 1.
    User naruto;
    // Impartial user 2.
    User sasuke;
    // Impartial user 3.
    User sakura;
    // Malicious user.
    User madara;
}

struct User {
    address payable account;
    uint256 privateKey;
}
