// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import { IEngine } from "@zaros/market-making/interfaces/IEngine.sol";

contract MockEngine is IEngine {
    function getUnrealizedDebt(uint128 marketId) external view override returns (int256) {
        return 0;
    }
}
