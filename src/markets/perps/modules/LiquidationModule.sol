// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { PerpsAccount } from "../storage/PerpsAccount.sol";

contract LiquidationModule {
    modifier onlyRegisteredLiquidator() {
        _;
    }

    function liquidateAccounts(uint128[] calldata accountsIds) external onlyRegisteredLiquidator { }
}
