// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import { Points } from "../storage/Points.sol";


contract PointsModuleTestnet {
    function getPointsOfUser(address user) external view returns (uint256 amount) {
        amount = Points.load(user).amount;
    }
}
