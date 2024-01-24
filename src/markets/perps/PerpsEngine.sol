// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { IDiamond } from "@zaros/diamonds/interfaces/IDiamond.sol";
import { Diamond } from "@zaros/diamonds/Diamond.sol";

contract PerpsEngine is Diamond {
    constructor(IDiamond.InitParams memory initParams) Diamond(initParams) { }

    receive() external payable { }
}
