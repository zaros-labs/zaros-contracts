// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { IUpgradeBranch } from "@zaros/tree-proxy/interfaces/IUpgradeBranch.sol";
import { ILookupBranch } from "@zaros/tree-proxy/interfaces/ILookupBranch.sol";
import { GlobalConfigurationBranch } from "../branches/GlobalConfigurationBranch.sol";
import { LiquidationBranch } from "../branches/LiquidationBranch.sol";
import { OrderBranch } from "../branches/OrderBranch.sol";
import { PerpMarketBranch } from "../branches/PerpMarketBranch.sol";
import { SettlementBranch } from "../branches/SettlementBranch.sol";
import { TradingAccountBranch } from "../branches/TradingAccountBranch.sol";

abstract contract IPerpsEngine is
    IUpgradeBranch,
    ILookupBranch,
    GlobalConfigurationBranch,
    LiquidationBranch,
    OrderBranch,
    PerpMarketBranch,
    SettlementBranch,
    TradingAccountBranch
{ }
