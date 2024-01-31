// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { AccountNFT } from "@zaros/account-nft/AccountNFT.sol";
import { IDiamond } from "@zaros/diamonds/interfaces/IDiamond.sol";
import { Diamond } from "@zaros/diamonds/Diamond.sol";
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
        address[] memory modules = deployModules();
        bytes4[][] memory modulesSelectors = getModulesSelectors();

        IDiamond.FacetCut[] memory facetCuts =
            getFacetCuts(modules, modulesSelectors, IDiamond.FacetCutAction.Replace);
        address[] memory initializables;
        bytes[] memory initializePayloads;

        perpsEngine = IPerpsEngine(vm.envAddress("PERPS_ENGINE_PROXY"));

        perpsEngine.updateModules(facetCuts, initializables, initializePayloads);

        logContracts(modules);
    }

    function logContracts(address[] memory modules) internal view {
        for (uint256 i = 0; i < modules.length; i++) {
            console.log("Module: ");
            console.log(modules[i]);
        }

        console.log("Perps Engine Proxy: ");
        console.log(address(perpsEngine));
    }
}
