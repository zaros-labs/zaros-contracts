// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { IDiamond } from "../interfaces/IDiamond.sol";
import { IDiamondCutModule } from "../interfaces/IDiamondCutModule.sol";
import { DiamondCut } from "../storage/DiamondCut.sol";

// Open Zeppelin dependencies
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";

// Open Zeppelin Upgradeable dependencies
import { Initializable } from "@openzeppelin-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/access/OwnableUpgradeable.sol";

contract DiamondCutModule is IDiamondCutModule, Initializable, OwnableUpgradeable {
    using DiamondCut for DiamondCut.Data;

    function initialize(address owner) external initializer {
        __Ownable_init(owner);
    }

    function updateModules(
        IDiamond.FacetCut[] memory facetCuts,
        address[] memory initializables,
        bytes[] memory initializePayloads
    )
        external
    {
        DiamondCut.Data storage diamondCut = DiamondCut.load();

        diamondCut.updateModules(facetCuts, initializables, initializePayloads);
    }

    function _authorizeUpgrade(IDiamond.FacetCut[] memory) internal onlyOwner { }
}
