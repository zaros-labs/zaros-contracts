// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { DiamondCut } from "./storage/DiamondCut.sol";
import { DiamondLoupe } from "./storage/DiamondLoupe.sol";
import { IDiamond } from "./interfaces/IDiamond.sol";

// Open Zeppelin dependencies
import { Proxy } from "@openzeppelin/contracts/proxy/Proxy.sol";

// Open Zeppelin Upgradeable dependencies
import { Initializable } from "@openzeppelin-upgradeable/proxy/utils/Initializable.sol";

contract DiamondModule is IDiamondModule, Proxy, Initializable {
    struct InitParams {
        FacetCut[] baseFacets;
        address init;
        bytes initData;
    }

    constructor(InitParams memory initDiamondCut) initializer {
        DiamondCut.diamondCut(initDiamondCut.baseFacets, initDiamondCut.init, initDiamondCut.initData);
    }

    function _implementation() internal view override returns (address facet) {
        bytes4 functionSignature = msg.sig;
        facet = DiamondLoupe.facetAddress(functionSignature);
        if (facet == address(0)) revert Errors.UnsupportedFunction(functionSignature);
    }
}
