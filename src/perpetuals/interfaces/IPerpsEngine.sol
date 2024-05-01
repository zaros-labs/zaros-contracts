// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { IUpgradeBranch } from "@zaros/tree-proxy/interfaces/IUpgradeBranch.sol";
import { ILookupBranch } from "@zaros/tree-proxy/interfaces/ILookupBranch.sol";
import { IGlobalConfigurationBranch } from "./IGlobalConfigurationBranch.sol";
import { ILiquidationBranch } from "./ILiquidationBranch.sol";
import { IOrderBranch } from "./IOrderBranch.sol";
import { IPerpMarketBranch } from "./IPerpMarketBranch.sol";
import { IPerpsAccountBranch } from "./IPerpsAccountBranch.sol";
import { ISettlementBranch } from "./ISettlementBranch.sol";

interface IPerpsEngine is
    IUpgradeBranch,
    ILookupBranch,
    IGlobalConfigurationBranch,
    ILiquidationBranch,
    IOrderBranch,
    IPerpMarketBranch,
    IPerpsAccountBranch,
    ISettlementBranch
{ }
