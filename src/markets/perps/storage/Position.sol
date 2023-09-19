//SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18 } from "@prb-math/SD59x18.sol";

/// @title The Position namespace.
library Position {
    /// @notice The {Position} namespace storage structure.
    /// @param size The position size in asset units, i.e amount of purchased contracts.
    /// @param initialMargin The notional value of the initial margin allocated by the account.
    /// @param unrealizedPnlStored The notional value of the realized profit or loss of the position.
    /// @param lastInteractionPrice The last settlement reference price of this position.
    /// @param lastInteractionFundingFeePerUnit The last funding fee per unit applied to this position.
    struct Data {
        int256 size;
        uint128 initialMargin;
        int128 unrealizedPnlStored;
        uint128 lastInteractionPrice;
        int128 lastInteractionFundingFeePerUnit;
    }

    /// @dev Updates the current position with the new one.
    /// @param self The position storage pointer.
    /// @param newPosition The new position to be placed.
    function updatePosition(Data storage self, Data memory newPosition) internal {
        self.size = newPosition.size;
        self.initialMargin = newPosition.initialMargin;
        self.unrealizedPnlStored = newPosition.unrealizedPnlStored;
        self.lastInteractionPrice = newPosition.lastInteractionPrice;
        self.lastInteractionFundingFeePerUnit = newPosition.lastInteractionFundingFeePerUnit;
    }

    /// @dev Clears the position data, used when a position is fully closed or liquidated.
    /// @param self The position storage pointer.
    function clear(Data storage self) internal {
        self.size = 0;
        self.initialMargin = 0;
        self.unrealizedPnlStored = 0;
        self.lastInteractionPrice = 0;
        self.lastInteractionFundingFeePerUnit = 0;
    }

    /// @dev Returns the accrued funding fee and the net funding fee per unit applied.
    /// @param self The position storage pointer.
    /// @param fundingFeePerUnit The market's current funding fee per unit.
    /// @return accruedFunding The accrued funding fee, positive or negative.
    /// @return netFundingFeePerUnit The net funding fee per unit applied to the position.
    function getAccruedFunding(
        Data storage self,
        SD59x18 fundingFeePerUnit
    )
        internal
        view
        returns (SD59x18 accruedFunding, SD59x18 netFundingFeePerUnit)
    {
        netFundingFeePerUnit = fundingFeePerUnit.sub(sd59x18(self.lastInteractionFundingFeePerUnit));
        accruedFunding = sd59x18(self.size).mul(netFundingFeePerUnit);
    }

    /// @dev Returns the current unrealized profit or loss of the position.
    /// @param self The position storage pointer.
    /// @param price The market's current reference price.
    /// @param accruedFunding The accrued funding fee, positive or negative.
    /// @return unrealizedPnl The current unrealized profit or loss of the position.
    function getUnrealizedPnl(
        Data storage self,
        UD60x18 price,
        SD59x18 accruedFunding
    )
        internal
        view
        returns (SD59x18 unrealizedPnl)
    {
        SD59x18 priceShift = price.intoSD59x18().sub(ud60x18(self.lastInteractionPrice).intoSD59x18());
        unrealizedPnl = sd59x18(self.size).mul(priceShift).add(accruedFunding).add(sd59x18(self.unrealizedPnlStored));
    }

    /// @dev Returns the notional value of the position.
    /// @param self The position storage pointer.
    /// @param price The market's current reference price.
    function getNotionalValue(Data storage self, UD60x18 price) internal view returns (UD60x18) {
        return sd59x18(self.size).abs().intoUD60x18().mul(price);
    }

    /// @dev Returns the entire position data.
    /// @param self The position storage pointer.
    /// @param maintenanceMarginRate The market's current maintenance margin rate.
    /// @param price The market's current reference price.
    /// @param fundingFeePerUnit The market's current funding fee per unit.
    /// @return size The position size in asset units, i.e amount of purchased contracts.
    /// @return initialMargin The notional value of the initial margin allocated by the account.
    /// @return notionalValue The notional value of the position.
    /// @return maintenanceMargin The notional value of the maintenance margin allocated by the account.
    /// @return accruedFunding The accrued funding fee.
    /// @return unrealizedPnl The current unrealized profit or loss of the position.
    function getPositionData(
        Data storage self,
        UD60x18 maintenanceMarginRate,
        UD60x18 price,
        SD59x18 fundingFeePerUnit
    )
        internal
        view
        returns (
            SD59x18 size,
            UD60x18 initialMargin,
            UD60x18 notionalValue,
            UD60x18 maintenanceMargin,
            SD59x18 accruedFunding,
            SD59x18 unrealizedPnl
        )
    {
        size = sd59x18(self.size);
        initialMargin = ud60x18(self.initialMargin);
        notionalValue = getNotionalValue(self, price);
        maintenanceMargin = notionalValue.mul(maintenanceMarginRate);
        (accruedFunding,) = getAccruedFunding(self, fundingFeePerUnit);
        unrealizedPnl = getUnrealizedPnl(self, price, accruedFunding);
    }
}
