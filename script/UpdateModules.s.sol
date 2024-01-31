// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { AccountNFT } from "@zaros/account-nft/AccountNFT.sol";
import { IDiamond } from "@zaros/diamonds/interfaces/IDiamond.sol";
import { Diamond } from "@zaros/diamonds/Diamond.sol";
import { OrderModule } from "@zaros/markets/perps/modules/OrderModule.sol";
import { PerpsEngine } from "@zaros/markets/perps/PerpsEngine.sol";
import { IPerpsEngine } from "@zaros/markets/perps/interfaces/IPerpsEngine.sol";
import { OrderFees } from "@zaros/markets/perps/storage/OrderFees.sol";
import { USDToken } from "@zaros/usd/USDToken.sol";
import { BaseScript } from "./Base.s.sol";
import { deployModules, getModulesSelectors, getFacetCuts } from "./utils/DiamondHelpers.sol";

// Open Zeppelin dependencies
import { ERC1967Proxy } from "@openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";

// Forge dependencies
import "forge-std/console.sol";

contract UpdateModules is BaseScript {
    /*//////////////////////////////////////////////////////////////////////////
                                    CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/
    IPerpsEngine internal perpsEngine;

    function run() public broadcaster {
        OrderModule orderModule = new OrderModule();

        bytes4[] memory selectors = new bytes4[](1);
        IDiamond.FacetCut[] memory facetCuts = new IDiamond.FacetCut[](1);
        address[] memory initializables;
        bytes[] memory initializePayloads;

        selectors[0] = OrderModule.simulateSettlement.selector;

        // come back here
        facetCuts[0] = IDiamond.FacetCut({
            facet: address(orderModule),
            action: IDiamond.FacetCutAction.Add,
            selectors: selectors
        });

        perpsEngine = IPerpsEngine(vm.envAddress("PERPS_ENGINE"));

        perpsEngine.updateModules(facetCuts, initializables, initializePayloads);

        console.log(address(orderModule));
    }
}
