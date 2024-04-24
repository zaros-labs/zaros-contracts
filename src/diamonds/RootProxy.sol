// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { DiamondCut } from "./storage/DiamondCut.sol";
import { IRootProxy } from "./interfaces/IRootProxy.sol";

// Open Zeppelin dependencies
import { Proxy } from "@openzeppelin/contracts/proxy/Proxy.sol";

abstract contract RootProxy is IRootProxy, Proxy {
    using DiamondCut for DiamondCut.Data;

    constructor(InitParams memory initDiamondCut) {
        DiamondCut.Data storage diamondCut = DiamondCut.load();

        diamondCut.updateModules(
            initDiamondCut.baseFacets, initDiamondCut.initializables, initDiamondCut.initializePayloads
        );
    }

    function _implementation() internal view override returns (address) {
        DiamondCut.Data storage diamondCut = DiamondCut.load();
        bytes4 functionSignature = msg.sig;

        address facet = diamondCut.getFacetAddress(functionSignature);
        if (facet == address(0)) revert Errors.UnsupportedFunction(functionSignature);

        return facet;
    }
}
