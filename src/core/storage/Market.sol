//SPDX-License-Identifier: MIT
pragma solidity >=0.8.11 <0.9.0;

// Zaros dependencies
import { CollateralConfig } from "./CollateralConfig.sol";
import { IMarket } from "../interfaces/external/IMarket.sol";

// Open Zeppelin dependencies
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

// PRB Math dependencies
import { UD60x18, ud60x18, ZERO as UD_ZERO, UNIT as UD_UNIT, MAX_UD60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18, ZERO as SD_ZERO } from "@prb-math/SD59x18.sol";

library Market {
    /**
     * @dev Thrown when a specified market is not found.
     */
    error MarketNotFound(uint128 marketId);

    /// @dev Constant base domain used to access a given market's storage slot
    string internal constant MARKET_DOMAIN = "fi.zaros.core.Market";

    struct Data {
        address marketAddress;
        int128 netIssuance;
        uint128 creditCapacity;
        int128 pendingDebt;
        int256 lastDebtPerCredit;
        uint128 depositedUSDCollateral;
        uint128 minLiquidityRatio;
        uint32 minDelegateTime;
    }

    function load(address marketAddress) internal pure returns (Data storage market) {
        bytes32 s = keccak256(abi.encode(MARKET_DOMAIN, marketAddress));
        assembly {
            market.slot := s
        }
    }

    function getDebtPerCredit(Data storage self) internal view returns (SD59x18) {
        return sd59x18(self.lastDebtPerCredit).add(
            totalDebt(self).add(sd59x18(self.pendingDebt)).div(ud60x18(self.creditCapacity).intoSD59x18())
        );
    }

    function getReportedDebt(Data storage self) internal view returns (UD60x18) {
        return ud60x18(IMarket(self.marketAddress).reportedDebt());
    }

    function getLockedCreditCapacity(Data storage self) internal view returns (UD60x18) {
        return ud60x18(IMarket(self.marketAddress).minimumCredit());
    }

    function totalDebt(Data storage self) internal view returns (SD59x18) {
        return getReportedDebt(self).intoSD59x18().add(sd59x18(self.netIssuance)).sub(
            ud60x18(self.depositedUSDCollateral).intoSD59x18()
        );
    }

    function getDepositedCollateralValue(Data storage self) internal view returns (UD60x18) {
        return ud60x18(self.depositedUSDCollateral);
    }

    function isCapacityLocked(Data storage self) internal view returns (bool) {
        return ud60x18(self.creditCapacity).lt(getLockedCreditCapacity(self));
    }

    function distributeDebt(Data storage self) internal returns (SD59x18) { }
}
