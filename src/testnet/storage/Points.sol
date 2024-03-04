// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { PointsConfig } from "../storage/PointsConfig.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18 } from "@prb-math/SD59x18.sol";

library Points {
    string internal constant POINTS_DOMAIN = "fi.zaros.Points";

    struct Data {
        int256 accumulatedPnl;
        uint256 pnlPointsCheckpoint;
        uint256 accumulatedTradingVolume;
        uint256 tradingVolumeCheckpoint;
        uint256 amount;
    }

    function load(address user) internal pure returns (Data storage points) {
        bytes32 slot = keccak256(abi.encode(POINTS_DOMAIN, user));

        assembly {
            points.slot := slot
        }
    }

    function updatePnlPoints(Data storage self, SD59x18 pnl) internal {
        self.accumulatedPnl += pnl.intoInt256();
        SD59x18 accumulatedPnl = sd59x18(self.accumulatedPnl);

        if (accumulatedPnl < sd59x18(10_000e18)) {
            return;
        }

        uint256 newPnlCheckpoint = accumulatedPnl.intoUD60x18().div(ud60x18(10_000e18)).sub(
            accumulatedPnl.intoUD60x18().mod(ud60x18(10_000e18))
        ).intoUint256();

        if (newPnlCheckpoint <= self.pnlPointsCheckpoint) {
            return;
        }

        uint256 checkpointsAdded = newPnlCheckpoint - self.pnlPointsCheckpoint;

        self.pnlPointsCheckpoint += checkpointsAdded;
        self.amount += checkpointsAdded * PointsConfig.POINTS_PER_10K_PNL;
    }

    function updateTradingVolumePoints(Data storage self, UD60x18 tradingVolume) internal {
        self.accumulatedTradingVolume += tradingVolume.intoUint256();
        UD60x18 accumulatedTradingVolume = ud60x18(self.accumulatedTradingVolume);

        if (accumulatedTradingVolume < ud60x18(10_000e18)) {
            return;
        }

        uint256 newTradingVolumeCheckpoint = accumulatedTradingVolume.div(ud60x18(10_000e18)).sub(
            accumulatedTradingVolume.mod(ud60x18(10_000e18))
        ).intoUint256();

        if (newTradingVolumeCheckpoint <= self.tradingVolumeCheckpoint) {
            return;
        }

        uint256 checkpointsAdded = newTradingVolumeCheckpoint - self.tradingVolumeCheckpoint;

        self.tradingVolumeCheckpoint += checkpointsAdded;
        self.amount += checkpointsAdded * PointsConfig.POINTS_PER_10K_TRADE_SIZE;
    }
}
