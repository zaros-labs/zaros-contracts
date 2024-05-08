// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { IUpgradeBranch } from "@zaros/tree-proxy/interfaces/IUpgradeBranch.sol";
import { ILookupBranch } from "@zaros/tree-proxy/interfaces/ILookupBranch.sol";
import { GlobalConfigurationBranch } from "@zaros/perpetuals/branches/GlobalConfigurationBranch.sol";
import { LiquidationBranch } from "@zaros/perpetuals/branches/LiquidationBranch.sol";
import { OrderBranch } from "@zaros/perpetuals/branches/OrderBranch.sol";
import { PerpMarketBranch } from "@zaros/perpetuals/branches/PerpMarketBranch.sol";
import { SettlementBranch } from "@zaros/perpetuals/branches/SettlementBranch.sol";
import { TradingAccountBranch } from "@zaros/perpetuals/branches/TradingAccountBranch.sol";

abstract contract IPerpsEngineTestnet is
    IUpgradeBranch,
    ILookupBranch,
    GlobalConfigurationBranch,
    LiquidationBranch,
    OrderBranch,
    PerpMarketBranch,
    SettlementBranch,
    TradingAccountBranch
{ }
