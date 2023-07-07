// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { IAggregatorV3 } from "../interfaces/external/chainlink/IAggregatorV3.sol";


library ChainlinkOracle {
    struct Data {
        address aggregator;
        uint8 decimals;
    }


    // TODO: implement
    // function getPrice()
}
