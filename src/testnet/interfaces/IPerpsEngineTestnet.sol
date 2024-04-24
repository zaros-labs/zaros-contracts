// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { IUpgradeBranch } from "@zaros/tree-proxy/interfaces/IUpgradeBranch.sol";
import { ILookupBranch } from "@zaros/tree-proxy/interfaces/ILookupBranch.sol";
import { IGlobalConfigurationBranchTestnet } from "./IGlobalConfigurationBranchTestnet.sol";
import { ILiquidationBranch } from "@zaros/perpetuals/interfaces/ILiquidationBranch.sol";
import { IOrderBranch } from "@zaros/perpetuals/interfaces/IOrderBranch.sol";
import { IPerpMarketBranch } from "@zaros/perpetuals/interfaces/IPerpMarketBranch.sol";
import { IPerpsAccountBranchTestnet } from "./IPerpsAccountBranchTestnet.sol";
import { ISettlementBranch } from "@zaros/perpetuals/interfaces/ISettlementBranch.sol";

interface IPerpsEngineTestnet is
    IUpgradeBranch,
    ILookupBranch,
    IGlobalConfigurationBranchTestnet,
    ILiquidationBranch,
    IOrderBranch,
    IPerpMarketBranch,
    IPerpsAccountBranchTestnet,
    ISettlementBranch
{ }
