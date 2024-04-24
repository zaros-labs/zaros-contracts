// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { AccountNFT } from "@zaros/account-nft/AccountNFT.sol";
import { IRootProxy } from "@zaros/tree-proxy/interfaces/IRootProxy.sol";
import { RootProxy } from "@zaros/tree-proxy/RootProxy.sol";
import { GlobalConfigurationBranchTestnet } from "@zaros/testnet/branches/GlobalConfigurationBranchTestnet.sol";
import { PerpsAccountBranchTestnet } from "@zaros/testnet/branches/PerpsAccountBranchTestnet.sol";
import { SettlementBranchTestnet } from "@zaros/testnet/branches/SettlementBranchTestnet.sol";
import { LimitedMintingERC20 } from "@zaros/testnet/LimitedMintingERC20.sol";
import { PerpsAccountBranch } from "@zaros/perpetuals/branches/PerpsAccountBranch.sol";
import { PerpMarketBranch } from "@zaros/perpetuals/branches/PerpMarketBranch.sol";
import { GlobalConfigurationBranch } from "@zaros/perpetuals/branches/GlobalConfigurationBranch.sol";
import { SettlementBranch } from "@zaros/perpetuals/branches/SettlementBranch.sol";
import { OrderBranch } from "@zaros/perpetuals/branches/OrderBranch.sol";
import { PerpsEngine } from "@zaros/perpetuals/PerpsEngine.sol";
import { IPerpsEngine } from "@zaros/perpetuals/interfaces/IPerpsEngine.sol";
import { OrderFees } from "@zaros/perpetuals/leaves/OrderFees.sol";
import { USDToken } from "@zaros/usd/USDToken.sol";
import { BaseScript } from "../Base.s.sol";
import { deployBranchs, getBranchsSelectors, getBranchUpgrades } from "../helpers/TreeProxyHelpers.sol";

// Open Zeppelin dependencies
import { ERC1967Proxy } from "@openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
import { UUPSUpgradeable } from "@openzeppelin/proxy/utils/UUPSUpgradeable.sol";

// Forge dependencies
import { console } from "forge-std/console.sol";

contract UpdateBranchs is BaseScript {
    /*//////////////////////////////////////////////////////////////////////////
                                    CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/
    IPerpsEngine internal perpsEngine;

    function run() public broadcaster {
        PerpsAccountBranchTestnet perpsAccountBranchTestnet = new PerpsAccountBranchTestnet();
        // PerpMarketBranch perpMarketBranch = new PerpMarketBranch();
        // GlobalConfigurationBranchTestnet globalConfigurationBranchTestnet = new GlobalConfigurationBranchTestnet();
        // SettlementBranchTestnet settlementBranchTestnet = new SettlementBranchTestnet();
        // OrderBranch orderBranch = new OrderBranch();

        // bytes4[] memory perpsAccountBranchTestnetSelectorsAdded = new bytes4[](1);
        bytes4[] memory perpsAccountBranchTestnetSelectorsUpdated = new bytes4[](1);
        // bytes4[] memory globalConfigurationBranchTestnetSelectorsAdded = new bytes4[](2);
        // bytes4[] memory settlementBranchTestnetSelectorsUpdated = new bytes4[](1);
        // bytes4[] memory orderBranchTestnetSelectorsUpdated = new bytes4[](1);

        // IRootProxy.BranchUpgrade[] memory branchUpgrades = new IRootProxy.BranchUpgrade[](4);

        // bytes4[] memory globalConfigurationBranchTestnetSelectorsAdded = new bytes4[](1);
        // bytes4[] memory perpMarketBranchSelectorsUpdated = new bytes4[](1);

        IRootProxy.BranchUpgrade[] memory branchUpgrades = new IRootProxy.BranchUpgrade[](1);

        address[] memory initializables;
        bytes[] memory initializePayloads;

        // perpsAccountBranchTestnetSelectorsAdded[0] = PerpsAccountBranch.getPositionState.selector;
        // perpsAccountBranchTestnetSelectorsAdded[1] = bytes4(keccak256("createPerpsAccount(bytes,bool)"));
        // perpsAccountBranchTestnetSelectorsAdded[2] = PerpsAccountBranchTestnet.getPointsOfUser.selector;
        // perpsAccountBranchTestnetSelectorsAdded[3] = PerpsAccountBranchTestnet.getUserReferralData.selector;
        // perpsAccountBranchTestnetSelectorsAdded[4] =
        // PerpsAccountBranchTestnet.getCustomReferralCodeReferee.selector;

        perpsAccountBranchTestnetSelectorsUpdated[0] = PerpsAccountBranchTestnet.getUserReferralData.selector;
        // perpsAccountBranchTestnetSelectorsUpdated[1] =
        // bytes4(keccak256("createPerpsAccountAndMulticall(bytes[])"));
        // perpsAccountBranchTestnetSelectorsUpdated[2] = bytes4(keccak256("depositMargin(uint128,address,uint256)"));

        // globalConfigurationBranchTestnetSelectorsAdded[0] =
        // GlobalConfigurationBranchTestnet.setUserPoints.selector;
        // globalConfigurationBranchTestnetSelectorsAdded[1] =
        //     GlobalConfigurationBranchTestnet.createCustomReferralCode.selector;

        // settlementBranchTestnetSelectorsUpdated[0] = SettlementBranch.fillMarketOrder.selector;
        // settlementBranchTestnetSelectorsUpdated[1] = SettlementBranch.fillCustomOrders.selector;

        // globalConfigurationBranchTestnetSelectorsAdded[0] =
        //     GlobalConfigurationBranch.updateSettlementConfiguration.selector;

        // perpMarketBranchSelectorsUpdated[0] = PerpMarketBranch.getOpenInterest.selector;

        // orderBranchTestnetSelectorsUpdated[0] = OrderBranch.createMarketOrder.selector;

        branchUpgrades[0] = (
            IRootProxy.BranchUpgrade({
                branch: address(perpsAccountBranchTestnet),
                action: IRootProxy.BranchUpgradeAction.Replace,
                selectors: perpsAccountBranchTestnetSelectorsUpdated
            })
        );

        // branchUpgrades[0] = (
        //     IRootProxy.BranchUpgrade({
        //         branch: address(perpsAccountBranchTestnet),
        //         action: IRootProxy.BranchUpgradeAction.Add,
        //         selectors: perpsAccountBranchTestnetSelectorsAdded
        //     })
        // );

        // branchUpgrades[1] = (
        //     IRootProxy.BranchUpgrade({
        //         branch: address(perpsAccountBranchTestnet),
        //         action: IRootProxy.BranchUpgradeAction.Replace,
        //         selectors: perpsAccountBranchTestnetSelectorsUpdated
        //     })
        // );

        // branchUpgrades[2] = (
        //     IRootProxy.BranchUpgrade({
        //         branch: address(globalConfigurationBranchTestnet),
        //         action: IRootProxy.BranchUpgradeAction.Add,
        //         selectors: globalConfigurationBranchTestnetSelectorsAdded
        //     })
        // );

        // branchUpgrades[3] = (
        //     IRootProxy.BranchUpgrade({
        //         branch: address(settlementBranchTestnet),
        //         action: IRootProxy.BranchUpgradeAction.Replace,
        //         selectors: settlementBranchTestnetSelectorsUpdated
        //     })
        // );

        perpsEngine = IPerpsEngine(vm.envAddress("PERPS_ENGINE"));

        perpsEngine.upgrade(branchUpgrades, initializables, initializePayloads);
    }
}
