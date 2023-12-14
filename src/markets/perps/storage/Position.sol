//SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18 } from "@prb-math/SD59x18.sol";

/// @title The Position namespace.
library Position {
    /// @notice Constant base domain used to access a given Position's storage slot.
    string internal constant POSITION_DOMAIN = "fi.zaros.markets.perps.storage.Position";

    /// @notice The {Position} namespace storage structure.
    /// @param size The position size in asset units, i.e amount of purchased contracts.
    /// @param unrealizedPnlStored The notional value of the realized profit or loss of the position.
    /// @param lastInteractionPrice The last settlement reference price of this position.
    /// @param lastInteractionFundingFeePerUnit The last funding fee per unit applied to this position.
    struct Data {
        int256 size;
        int128 unrealizedPnlStored;
        uint128 lastInteractionPrice;
        int128 lastInteractionFundingFeePerUnit;
    }

    function load(uint128 accountId, uint128 marketId) internal pure returns (Data storage position) {
        bytes32 slot = keccak256(abi.encode(POSITION_DOMAIN, accountId, marketId));

        assembly {
            position.slot := slot
        }
    }

    /// @dev Updates the current position with the new one.
    /// @param self The position storage pointer.
    /// @param newPosition The new position to be placed.
    function update(Data storage self, Data memory newPosition) internal {
        self.size = newPosition.size;
        self.unrealizedPnlStored = newPosition.unrealizedPnlStored;
        self.lastInteractionPrice = newPosition.lastInteractionPrice;
        self.lastInteractionFundingFeePerUnit = newPosition.lastInteractionFundingFeePerUnit;
    }

    /// @dev Clears the position data, used when a position is fully closed or liquidated.
    /// @param self The position storage pointer.
    function clear(Data storage self) internal {
        self.size = 0;
        self.unrealizedPnlStored = 0;
        self.lastInteractionPrice = 0;
        self.lastInteractionFundingFeePerUnit = 0;
    }

    /// @dev Returns the accrued funding fee and the net funding fee per unit applied.
    /// @param self The position storage pointer.
    /// @param fundingFeePerUnit The market's current funding fee per unit.
    /// @return accruedFunding The accrued funding fee, positive or negative.
    function getAccruedFunding(
        Data storage self,
        SD59x18 fundingFeePerUnit
    )
        internal
        view
        returns (SD59x18 accruedFunding)
    {
        SD59x18 netFundingFeePerUnit = fundingFeePerUnit.sub(sd59x18(self.lastInteractionFundingFeePerUnit));
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
            UD60x18 notionalValue,
            UD60x18 maintenanceMargin,
            SD59x18 accruedFunding,
            SD59x18 unrealizedPnl
        )
    {
        size = sd59x18(self.size);
        notionalValue = getNotionalValue(self, price);
        maintenanceMargin = notionalValue.mul(maintenanceMarginRate);
        accruedFunding = getAccruedFunding(self, fundingFeePerUnit);
        unrealizedPnl = getUnrealizedPnl(self, price, accruedFunding);
    }
}
