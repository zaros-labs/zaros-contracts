// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { GlobalConfigurationModule } from "@zaros/markets/perps/modules/GlobalConfigurationModule.sol";
import { Points } from "../storage/Points.sol";


contract GlobalConfigurationModuleTestnet is GlobalConfigurationModule {
    function getPointsOfUser(address user) external view returns (uint256 amount) {
        amount = Points.load(user).amount;
    }

    function setUserPoints(address user, uint256 value) external onlyOwner {
        Points.load(user).amount = value;
    }
}
