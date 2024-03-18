// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { AccountNFT } from "@zaros/account-nft/AccountNFT.sol";
import { IDiamond } from "@zaros/diamonds/interfaces/IDiamond.sol";
import { Diamond } from "@zaros/diamonds/Diamond.sol";
import { GlobalConfigurationModuleTestnet } from "@zaros/testnet/modules/GlobalConfigurationModuleTestnet.sol";
import { PerpsAccountModuleTestnet } from "@zaros/testnet/modules/PerpsAccountModuleTestnet.sol";
import { SettlementModuleTestnet } from "@zaros/testnet/modules/SettlementModuleTestnet.sol";
import { LimitedMintingERC20 } from "@zaros/testnet/LimitedMintingERC20.sol";
import { PerpsAccountModule } from "@zaros/markets/perps/modules/PerpsAccountModule.sol";
import { PerpMarketModule } from "@zaros/markets/perps/modules/PerpMarketModule.sol";
import { GlobalConfigurationModule } from "@zaros/markets/perps/modules/GlobalConfigurationModule.sol";
import { SettlementModule } from "@zaros/markets/perps/modules/SettlementModule.sol";
import { OrderModule } from "@zaros/markets/perps/modules/OrderModule.sol";
import { PerpsEngine } from "@zaros/markets/perps/PerpsEngine.sol";
import { IPerpsEngine } from "@zaros/markets/perps/interfaces/IPerpsEngine.sol";
import { OrderFees } from "@zaros/markets/perps/storage/OrderFees.sol";
import { USDToken } from "@zaros/usd/USDToken.sol";
import { BaseScript } from "../Base.s.sol";
import { deployModules, getModulesSelectors, getFacetCuts } from "../helpers/DiamondHelpers.sol";

// import { MockSettlementModule } from "test/mocks/MockSettlementModule.sol";

// Open Zeppelin dependencies
import { ERC1967Proxy } from "@openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
import { UUPSUpgradeable } from "@openzeppelin/proxy/utils/UUPSUpgradeable.sol";

// Forge dependencies
import { console } from "forge-std/console.sol";

contract UpdateModules is BaseScript {
    /*//////////////////////////////////////////////////////////////////////////
                                    CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/
    IPerpsEngine internal perpsEngine;

    function run() public broadcaster {
        // PerpsAccountModuleTestnet perpsAccountModuleTestnet = new PerpsAccountModuleTestnet();
        // PerpMarketModule perpMarketModule = new PerpMarketModule();
        // GlobalConfigurationModuleTestnet globalConfigurationModuleTestnet = new GlobalConfigurationModuleTestnet();
        // SettlementModuleTestnet settlementModuleTestnet = new SettlementModuleTestnet();
        OrderModule orderModule = new OrderModule();

        // bytes4[] memory perpsAccountModuleTestnetSelectorsAdded = new bytes4[](1);
        // bytes4[] memory perpsAccountModuleTestnetSelectorsUpdated = new bytes4[](3);
        // bytes4[] memory globalConfigurationModuleTestnetSelectorsAdded = new bytes4[](2);
        // bytes4[] memory settlementModuleTestnetSelectorsUpdated = new bytes4[](1);
        bytes4[] memory orderModuleTestnetSelectorsUpdated = new bytes4[](1);

        // IDiamond.FacetCut[] memory facetCuts = new IDiamond.FacetCut[](4);

        // bytes4[] memory globalConfigurationModuleTestnetSelectorsAdded = new bytes4[](1);
        // bytes4[] memory perpMarketModuleSelectorsUpdated = new bytes4[](1);

        IDiamond.FacetCut[] memory facetCuts = new IDiamond.FacetCut[](1);

        address[] memory initializables;
        bytes[] memory initializePayloads;

        // perpsAccountModuleTestnetSelectorsAdded[0] = PerpsAccountModule.getPositionState.selector;
        // perpsAccountModuleTestnetSelectorsAdded[1] = bytes4(keccak256("createPerpsAccount(bytes,bool)"));
        // perpsAccountModuleTestnetSelectorsAdded[2] = PerpsAccountModuleTestnet.getPointsOfUser.selector;
        // perpsAccountModuleTestnetSelectorsAdded[3] = PerpsAccountModuleTestnet.getUserReferralData.selector;
        // perpsAccountModuleTestnetSelectorsAdded[4] =
        // PerpsAccountModuleTestnet.getCustomReferralCodeReferee.selector;

        // perpsAccountModuleTestnetSelectorsUpdated[0] = bytes4(keccak256("createPerpsAccount()"));
        // perpsAccountModuleTestnetSelectorsUpdated[1] =
        // bytes4(keccak256("createPerpsAccountAndMulticall(bytes[])"));
        // perpsAccountModuleTestnetSelectorsUpdated[2] = bytes4(keccak256("depositMargin(uint128,address,uint256)"));

        // globalConfigurationModuleTestnetSelectorsAdded[0] =
        // GlobalConfigurationModuleTestnet.setUserPoints.selector;
        // globalConfigurationModuleTestnetSelectorsAdded[1] =
        //     GlobalConfigurationModuleTestnet.createCustomReferralCode.selector;

        // settlementModuleTestnetSelectorsUpdated[0] = SettlementModule.settleMarketOrder.selector;
        // settlementModuleTestnetSelectorsUpdated[1] = SettlementModule.settleCustomOrders.selector;

        // globalConfigurationModuleTestnetSelectorsAdded[0] =
        //     GlobalConfigurationModule.updateSettlementConfiguration.selector;

        // perpMarketModuleSelectorsUpdated[0] = PerpMarketModule.getOpenInterest.selector;

        orderModuleTestnetSelectorsUpdated[0] = OrderModule.createMarketOrder.selector;

        facetCuts[0] = (
            IDiamond.FacetCut({
                facet: address(orderModule),
                action: IDiamond.FacetCutAction.Replace,
                selectors: orderModuleTestnetSelectorsUpdated
            })
        );

        // facetCuts[0] = (
        //     IDiamond.FacetCut({
        //         facet: address(perpsAccountModuleTestnet),
        //         action: IDiamond.FacetCutAction.Add,
        //         selectors: perpsAccountModuleTestnetSelectorsAdded
        //     })
        // );

        // facetCuts[1] = (
        //     IDiamond.FacetCut({
        //         facet: address(perpsAccountModuleTestnet),
        //         action: IDiamond.FacetCutAction.Replace,
        //         selectors: perpsAccountModuleTestnetSelectorsUpdated
        //     })
        // );

        // facetCuts[2] = (
        //     IDiamond.FacetCut({
        //         facet: address(globalConfigurationModuleTestnet),
        //         action: IDiamond.FacetCutAction.Add,
        //         selectors: globalConfigurationModuleTestnetSelectorsAdded
        //     })
        // );

        // facetCuts[3] = (
        //     IDiamond.FacetCut({
        //         facet: address(settlementModuleTestnet),
        //         action: IDiamond.FacetCutAction.Replace,
        //         selectors: settlementModuleTestnetSelectorsUpdated
        //     })
        // );

        // bytes4[] memory mockSelectors = new bytes4[](2);

        // mockSelectors[0] = MockSettlementModule.mockSettleMarketOrder.selector;
        // mockSelectors[1] = MockSettlementModule.mockSettleCustomOrders.selector;

        // facetCuts[1] = IDiamond.FacetCut({
        //     facet: address(mockSettlementModule),
        //     action: IDiamond.FacetCutAction.Add,
        //     selectors: mockSelectors
        // });

        perpsEngine = IPerpsEngine(vm.envAddress("PERPS_ENGINE"));

        perpsEngine.updateModules(facetCuts, initializables, initializePayloads);
    }
}
