// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

library Points {
    string internal constant POINTS_DOMAIN = "fi.zaros.Points";

    struct Data {
        uint256 amount;
    }

    function load(address user) internal pure returns (Data storage points) {
        bytes32 slot = keccak256(abi.encode(POINTS_DOMAIN, user));

        assembly {
            points.slot := slot
        }
    }
}
