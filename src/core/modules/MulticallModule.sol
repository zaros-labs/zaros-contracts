// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { Multicall } from "@zaros/utils/Multicall.sol";

contract MulticallModule {
    function multicall(bytes[] calldata data) external payable returns (bytes[] memory results) {
        return Multicall.execute(data);
    }
}
