// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;


library Points {
    string internal constant POINTS_CONFIG_DOMAIN = "fi.zaros.PointsConfig";

    struct Data {
        uint256 pointsPerOrderValue;
    }

    function load(address user) internal pure returns (Data storage points) {
        bytes32 slot = keccak256(abi.encode(POINTS_CONFIG_DOMAIN));
        assembly {
            points.slot := slot
        }
    }
}

