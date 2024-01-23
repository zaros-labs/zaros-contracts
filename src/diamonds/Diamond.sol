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

contract DiamondModule is IDiamond, Proxy, Initializable {
    using DiamondCut for DiamondCut.Data;

    struct InitParams {
        FacetCut[] baseFacets;
        address init;
        bytes initData;
    }

    constructor(InitParams memory initDiamondCut) initializer {
        DiamondCut.Data storage diamondCut = DiamondCut.load();

        diamondCut.updateModules(initDiamondCut.baseFacets, initDiamondCut.init, initDiamondCut.initData);
    }

    function _implementation() internal view override returns (address) {
        DiamondCut.Data storage diamondCut = DiamondCut.load();
        bytes4 functionSignature = msg.sig;

        address facet = diamondCut.getFacetAddress(functionSignature);
        if (facet == address(0)) revert Errors.UnsupportedFunction(functionSignature);

        return facet;
    }
}
