// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import { Proxy } from "@openzeppelin/contracts/proxy/Proxy.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { DiamondCutModule } from "src/facets/cut/DiamondCutBase.sol";
import { DiamondLoupeModule } from "src/facets/loupe/DiamondLoupeBase.sol";
import { IDiamond } from "./IDiamond.sol";

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
