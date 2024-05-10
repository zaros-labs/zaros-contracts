// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { RootProxy } from "../RootProxy.sol";
import { RootUpgrade } from "../leaves/RootUpgrade.sol";

// Open Zeppelin dependencies
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";

// Open Zeppelin Upgradeable dependencies
import { Initializable } from "@openzeppelin-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title RootUpgrade
 * @notice Interface of the RootUpgrade branch. See [EIP-2535](https://eips.ethereum.org/EIPS/eip-2535).
 */
contract UpgradeBranch is Initializable, OwnableUpgradeable {
    using RootUpgrade for RootUpgrade.Data;

    function initialize(address owner) external initializer {
        __Ownable_init(owner);
    }

    /**
     * @notice Add/replace/remove any number of functions and optionally execute
     *         a function with delegatecall.
     * @param branchUpgrades Contains the branch addresses and function selectors.
     * @param initializables The addresses of the contracts or branches to execute initializePayloads.
     * @param initializePayloads An array of function calls, including function selectors and arguments
     *                 executed with delegatecall on each initializable contract.
     */
    function upgrade(
        RootProxy.BranchUpgrade[] memory branchUpgrades,
        address[] memory initializables,
        bytes[] memory initializePayloads
    )
        external
    {
        _authorizeUpgrade(branchUpgrades);
        RootUpgrade.Data storage rootUpgrade = RootUpgrade.load();

        rootUpgrade.upgrade(branchUpgrades, initializables, initializePayloads);
    }

    function _authorizeUpgrade(RootProxy.BranchUpgrade[] memory) internal onlyOwner { }
}
