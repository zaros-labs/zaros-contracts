// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import { IEngine } from "@zaros/market-making/interfaces/IEngine.sol";

contract MockEngine is IEngine {
    int256 public totalDebt = 0;

    function getUnrealizedDebt(uint128) external view override returns (int256) {
        return totalDebt;
    }
}
