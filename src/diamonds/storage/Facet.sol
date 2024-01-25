// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

library Facet {
    struct Data {
        address facet;
        bytes4[] selectors;
    }
}
