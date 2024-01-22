// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { DiamondCutModule } from "./modules/DiamondCutModule.sol";
import { DiamondLoupeModule } from "./modules/DiamondLoupeModule.sol";
import { IDiamond } from "./interfaces/IDiamond.sol";

// Open Zeppelin dependencies
import { Proxy } from "@openzeppelin/contracts/proxy/Proxy.sol";

// Open Zeppelin Upgradeable dependencies
import { Initializable } from "@openzeppelin-upgradeable/proxy/utils/Initializable.sol";

contract DiamondModule is IDiamondModule, Proxy, DiamondCutModule, DiamondLoupeModule, Initializable {
    struct InitParams {
        FacetCut[] baseFacets;
        address init;
        bytes initData;
    }

    constructor(InitParams memory initDiamondCut) initializer {
        _diamondCut(initDiamondCut.baseFacets, initDiamondCut.init, initDiamondCut.initData);
    }

    function _implementation() internal view override returns (address facet) {
        facet = _facetAddress(msg.sig);
        if (facet == address(0)) revert Diamond_UnsupportedFunction();
    }
}
